require 'action_dispatch/session/active_record_store'
require "active_record/session_store/extension/logger_silencer"

module ActiveRecord
  module SessionStore
    module ClassMethods # :nodoc:
      def marshal(data)
        ::Base64.encode64(Marshal.dump(data)) if data
      end

      def unmarshal(data)
        Marshal.load(::Base64.decode64(data)) if data
      end

      def drop_table!
        if connection.schema_cache.respond_to?(:clear_data_source_cache!)
          connection.schema_cache.clear_data_source_cache!(table_name)
        else
          connection.schema_cache.clear_table_cache!(table_name)
        end
        connection.drop_table table_name
      end

      def create_table!
        if connection.schema_cache.respond_to?(:clear_data_source_cache!)
          connection.schema_cache.clear_data_source_cache!(table_name)
        else
          connection.schema_cache.clear_table_cache!(table_name)
        end
        connection.create_table(table_name) do |t|
          t.string session_id_column, :limit => 255
          t.text data_column_name
        end
        connection.add_index table_name, session_id_column, :unique => true
      end
    end
  end
end

require 'active_record/session_store/session'
require 'active_record/session_store/sql_bypass'
require 'active_record/session_store/railtie' if defined?(Rails)

ActionDispatch::Session::ActiveRecordStore.session_class = ActiveRecord::SessionStore::Session
Logger.send :include, ActiveRecord::SessionStore::Extension::LoggerSilencer

begin
  require "syslog/logger"
  Syslog::Logger.send :include, ActiveRecord::SessionStore::Extension::LoggerSilencer
rescue LoadError; end
