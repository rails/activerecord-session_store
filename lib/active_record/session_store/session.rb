require "active_support/core_ext/module/attribute_accessors"

module ActiveRecord
  module SessionStore
    # The default Active Record class.
    class Session < ActiveRecord::Base
      extend ClassMethods

      ##
      # :singleton-method:
      # Customizable data column name. Defaults to 'data'.
      cattr_accessor :data_column_name
      self.data_column_name = 'data'

      before_save :marshal_data!
      before_save :raise_on_session_data_overflow!

      # This method is defiend in `protected_attributes` gem. We can't check for
      # `attr_accessible` as Rails also define this and raise `RuntimeError`
      # telling you to use the gem.
      if respond_to?(:accessible_attributes)
        attr_accessible :session_id, :data
      end

      class << self
        def data_column_size_limit
          @data_column_size_limit ||= columns_hash[data_column_name].limit
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
              def self.find_by_session_id(*args)
                find_by_sessid(*args)
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

      # Lazy-unmarshal session state.
      def data
        @data ||= self.class.unmarshal(read_attribute(@@data_column_name)) || {}
      end

      attr_writer :data

      # Has the session been loaded yet?
      def loaded?
        @data
      end

      private
        def marshal_data!
          return false unless loaded?
          write_attribute(@@data_column_name, self.class.marshal(data))
        end

        # Ensures that the data about to be stored in the database is not
        # larger than the data storage column. Raises
        # ActionController::SessionOverflowError.
        def raise_on_session_data_overflow!
          return false unless loaded?
          limit = self.class.data_column_size_limit
          if limit and read_attribute(@@data_column_name).size > limit
            raise ActionController::SessionOverflowError
          end
        end
    end
  end
end
