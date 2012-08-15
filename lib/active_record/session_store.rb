require 'action_dispatch/session/active_record_store'

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
        connection.schema_cache.clear_table_cache!(table_name)
        connection.drop_table table_name
      end

      def create_table!
        connection.schema_cache.clear_table_cache!(table_name)
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
