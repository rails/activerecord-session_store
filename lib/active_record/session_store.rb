require 'action_dispatch/session/active_record_store'
require "active_record/session_store/extension/logger_silencer"

module ActiveRecord
  module SessionStore
    module ClassMethods # :nodoc:
      cattr_accessor :serializer

      def serialize(data)
        determine_serializer.dump(data) if data
      end

      def deserialize(data)
        determine_serializer.load(data) if data
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

      def determine_serializer
        self.serializer ||= :marshal
        case self.serializer
          when :marshal then MarshalSerializer
          when :json    then JsonSerializer
          when :hybrid  then HybridSerializer
          else self.serializer
        end
      end

      # Use Marshal with Base64 encoding
      class MarshalSerializer
        def self.load(value)
          Marshal.load(::Base64.decode64(value))
        end

        def self.dump(value)
          ::Base64.encode64(Marshal.dump(value))
        end
      end

      # Uses built-in JSON library to encode/decode session
      class JsonSerializer
        def self.load(value)
          JSON.parse(value, quirks_mode: true)
        end

        def self.dump(value)
          JSON.generate(value, quirks_mode: true)
        end
      end

      # Transparently migrates existing session values from Marshal to JSON
      class HybridSerializer < JsonSerializer
        MARSHAL_SIGNATURE = 'BAh'.freeze

        def self.load(value)
          if needs_migration?(value)
            Marshal.load(::Base64.decode64(value))
          else
            super
          end
        end

        def self.needs_migration?(value)
          value.start_with?(MARSHAL_SIGNATURE)
        end
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
