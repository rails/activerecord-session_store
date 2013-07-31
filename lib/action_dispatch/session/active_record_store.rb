require 'action_dispatch/middleware/session/abstract_store'

module ActionDispatch
  module Session
    # = Active Record Session Store
    #
    # A session store backed by an Active Record class. A default class is
    # provided, but any object duck-typing to an Active Record Session class
    # with text +session_id+ and +data+ attributes is sufficient.
    #
    # The default assumes a +sessions+ tables with columns:
    #   +id+ (numeric primary key),
    #   +session_id+ (string, usually varchar; maximum length is 255), and
    #   +data+ (text or longtext; careful if your session data exceeds 65KB).
    #
    # The +session_id+ column should always be indexed for speedy lookups.
    # Session data is marshaled to the +data+ column in Base64 format.
    # If the data you write is larger than the column's size limit,
    # ActionController::SessionOverflowError will be raised.
    #
    # You may configure the table name, primary key, and data column.
    # For example, at the end of <tt>config/application.rb</tt>:
    #
    #   ActiveRecord::SessionStore::Session.table_name = 'legacy_session_table'
    #   ActiveRecord::SessionStore::Session.primary_key = 'session_id'
    #   ActiveRecord::SessionStore::Session.data_column_name = 'legacy_session_data'
    #
    # Note that setting the primary key to the +session_id+ frees you from
    # having a separate +id+ column if you don't want it. However, you must
    # set <tt>session.model.id = session.session_id</tt> by hand!  A before filter
    # on ApplicationController is a good place.
    #
    # Since the default class is a simple Active Record, you get timestamps
    # for free if you add +created_at+ and +updated_at+ datetime columns to
    # the +sessions+ table, making periodic session expiration a snap.
    #
    # You may provide your own session class implementation, whether a
    # feature-packed Active Record or a bare-metal high-performance SQL
    # store, by setting
    #
    #   ActionDispatch::Session::ActiveRecordStore.session_class = MySessionClass
    #
    # You must implement these methods:
    #
    #   self.find_by_session_id(session_id)
    #   initialize(hash_of_session_id_and_data, options_hash = {})
    #   attr_reader :session_id
    #   attr_accessor :data
    #   save
    #   destroy
    #
    # The example SqlBypass class is a generic SQL session store. You may
    # use it as a basis for high-performance database-specific stores.
    class ActiveRecordStore < ActionDispatch::Session::AbstractStore
      # The class used for session storage. Defaults to
      # ActiveRecord::SessionStore::Session
      cattr_accessor :session_class

      SESSION_RECORD_KEY = 'rack.session.record'
      ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY

      private
        def get_session(env, sid)
          ActiveRecord::Base.logger.quietly do
            unless sid and session = @@session_class.find_by_session_id(sid)
              # If the sid was nil or if there is no pre-existing session under the sid,
              # force the generation of a new sid and associate a new session associated with the new sid
              sid = generate_sid
              session = @@session_class.new(:session_id => sid, :data => {})
            end
            env[SESSION_RECORD_KEY] = session
            [sid, session.data]
          end
        end

        def set_session(env, sid, session_data, options)
          ActiveRecord::Base.logger.quietly do
            record = get_session_model(env, sid)
            record.data = session_data
            record.session_id= sid
            return false unless record.save

            session_data = record.data
            if session_data && session_data.respond_to?(:each_value)
              session_data.each_value do |obj|
                obj.clear_association_cache if obj.respond_to?(:clear_association_cache)
              end
            end
          end

          sid
        end

        def destroy_session(env, session_id, options)
          if sid = current_session_id(env)
            ActiveRecord::Base.logger.quietly do
              get_session_model(env, sid).destroy
              env[SESSION_RECORD_KEY] = nil
            end
          end

          generate_sid unless options[:drop]
        end

        def get_session_model(env, sid)
          if env[ENV_SESSION_OPTIONS_KEY][:id].nil?
            env[SESSION_RECORD_KEY] = find_session(sid)
          else
            env[SESSION_RECORD_KEY] ||= find_session(sid)
          end
        end

        def find_session(id)
          @@session_class.find_by_session_id(id) ||
            @@session_class.new(:session_id => id, :data => {})
        end
    end
  end
end
