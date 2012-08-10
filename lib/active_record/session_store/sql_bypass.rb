module ActiveRecord
  module SessionStore
    # A barebones session store which duck-types with the default session
    # store but bypasses Active Record and issues SQL directly. This is
    # an example session model class meant as a basis for your own classes.
    #
    # The database connection, table name, and session id and data columns
    # are configurable class attributes. Marshaling and unmarshaling
    # are implemented as class methods that you may override. By default,
    # marshaling data is
    #
    #   ::Base64.encode64(Marshal.dump(data))
    #
    # and unmarshaling data is
    #
    #   Marshal.load(::Base64.decode64(data))
    #
    # This marshaling behavior is intended to store the widest range of
    # binary session data in a +text+ column. For higher performance,
    # store in a +blob+ column instead and forgo the Base64 encoding.
    class SqlBypass
      extend ClassMethods

      ##
      # :singleton-method:
      # The table name defaults to 'sessions'.
      cattr_accessor :table_name
      @@table_name = 'sessions'

      ##
      # :singleton-method:
      # The session id field defaults to 'session_id'.
      cattr_accessor :session_id_column
      @@session_id_column = 'session_id'

      ##
      # :singleton-method:
      # The data field defaults to 'data'.
      cattr_accessor :data_column
      @@data_column = 'data'

      class << self
        alias :data_column_name :data_column

        # Use the ActiveRecord::Base.connection by default.
        attr_writer :connection

        # Use the ActiveRecord::Base.connection_pool by default.
        attr_writer :connection_pool

        def connection
          @connection ||= ActiveRecord::Base.connection
        end

        def connection_pool
          @connection_pool ||= ActiveRecord::Base.connection_pool
        end

        # Look up a session by id and unmarshal its data if found.
        def find_by_session_id(session_id)
          if record = connection.select_one("SELECT #{connection.quote_column_name(data_column)} AS data FROM #{@@table_name} WHERE #{connection.quote_column_name(@@session_id_column)}=#{connection.quote(session_id.to_s)}")
            new(:session_id => session_id, :marshaled_data => record['data'])
          end
        end
      end

      delegate :connection, :connection=, :connection_pool, :connection_pool=, :to => self

      attr_reader :session_id, :new_record
      alias :new_record? :new_record

      attr_writer :data

      # Look for normal and marshaled data, self.find_by_session_id's way of
      # telling us to postpone unmarshaling until the data is requested.
      # We need to handle a normal data attribute in case of a new record.
      def initialize(attributes)
        @session_id     = attributes[:session_id]
        @data           = attributes[:data]
        @marshaled_data = attributes[:marshaled_data]
        @new_record     = @marshaled_data.nil?
      end

      # Returns true if the record is persisted, i.e. it's not a new record
      def persisted?
        !@new_record
      end

      # Lazy-unmarshal session state.
      def data
        unless @data
          if @marshaled_data
            @data, @marshaled_data = self.class.unmarshal(@marshaled_data) || {}, nil
          else
            @data = {}
          end
        end
        @data
      end

      def loaded?
        @data
      end

      def save
        return false unless loaded?
        marshaled_data = self.class.marshal(data)
        connect        = connection

        if @new_record
          @new_record = false
          connect.update <<-end_sql, 'Create session'
            INSERT INTO #{table_name} (
              #{connect.quote_column_name(session_id_column)},
              #{connect.quote_column_name(data_column)} )
            VALUES (
              #{connect.quote(session_id)},
              #{connect.quote(marshaled_data)} )
          end_sql
        else
          connect.update <<-end_sql, 'Update session'
            UPDATE #{table_name}
            SET #{connect.quote_column_name(data_column)}=#{connect.quote(marshaled_data)}
            WHERE #{connect.quote_column_name(session_id_column)}=#{connect.quote(session_id)}
          end_sql
        end
      end

      def destroy
        return if @new_record

        connect = connection
        connect.delete <<-end_sql, 'Destroy session'
          DELETE FROM #{table_name}
          WHERE #{connect.quote_column_name(session_id_column)}=#{connect.quote(session_id.to_s)}
        end_sql
      end
    end
  end
end
