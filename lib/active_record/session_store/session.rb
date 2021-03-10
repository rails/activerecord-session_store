require "active_support/core_ext/module/attribute_accessors"
require "thread"

module ActiveRecord
  module SessionStore
    # The default Active Record class.
    class Session < ActiveRecord::Base
      extend ClassMethods
      SEMAPHORE = Mutex.new

      ##
      # :singleton-method:
      # Customizable data column name. Defaults to 'data'.
      cattr_accessor :data_column_name
      self.data_column_name = 'data'

      before_save :serialize_data!
      before_save :raise_on_session_data_overflow!

      class << self
        def data_column_size_limit
          @data_column_size_limit ||= columns_hash[data_column_name].limit
        end

        # Hook to set up sessid compatibility.
        def find_by_session_id(session_id)
          SEMAPHORE.synchronize { setup_sessid_compatibility! }
          find_by_session_id(session_id)
        end

        private
          def session_id_column
            'session_id'
          end

          # Compatibility with tables using sessid instead of session_id.
          def setup_sessid_compatibility!
            # Reset column info since it may be stale.
            reset_column_information
            if columns_hash['sessid']
              def self.find_by_session_id(session_id)
                find_by_sessid(session_id)
              end

              define_method(:session_id)  { sessid }
              define_method(:session_id=) { |session_id| self.sessid = session_id }
            else
              class << self; remove_possible_method :find_by_session_id; end

              def self.find_by_session_id(session_id)
                where(session_id: session_id).first
              end
            end
          end
      end

      def initialize(*)
        @data = nil
        super
      end

      # Lazy-deserialize session state.
      def data
        @data ||= self.class.deserialize(read_attribute(@@data_column_name)) || {}
      end

      attr_writer :data

      # Has the session been loaded yet?
      def loaded?
        @data
      end

      # This method was introduced when addressing CVE-2019-16782
      # (see https://github.com/rack/rack/security/advisories/GHSA-hrqr-hxpp-chr3).
      # Sessions created on version <= 1.1.3 were guessable via a timing attack.
      # To secure sessions created on those old versions, this method can be called
      # on all existing sessions in the database. Users will not lose their session
      # when this is done.
      def secure!
        session_id_column = if self.class.columns_hash['sessid']
          :sessid
        else
          :session_id
        end
        raw_session_id = read_attribute(session_id_column)
        if ActionDispatch::Session::ActiveRecordStore.private_session_id?(raw_session_id)
          # is already private, nothing to do
        else
          session_id_object = Rack::Session::SessionId.new(raw_session_id)
          update_column(session_id_column, session_id_object.private_id)
        end
      end

      private
        def serialize_data!
          unless loaded?
            throw :abort
          end
          write_attribute(@@data_column_name, self.class.serialize(data))
        end

        # Ensures that the data about to be stored in the database is not
        # larger than the data storage column. Raises
        # ActionController::SessionOverflowError.
        def raise_on_session_data_overflow!
          unless loaded?
            throw :abort
          end
          limit = self.class.data_column_size_limit
          if limit and read_attribute(@@data_column_name).size > limit
            raise ActionController::SessionOverflowError
          end
        end
    end
  end
end

ActionDispatch::Session::ActiveRecordStore.session_class = ActiveRecord::SessionStore::Session
