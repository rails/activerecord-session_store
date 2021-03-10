require 'helper'
require 'active_record/session_store'
require 'active_support/core_ext/hash/keys'

module ActiveRecord
  module SessionStore
    class SessionTest < ActiveSupport::TestCase

      attr_reader :session_klass

      def setup
        super
        ActiveRecord::Base.connection.schema_cache.clear!
        Session.drop_table! if Session.table_exists?
        @session_klass = Class.new(Session)
        ActiveRecord::SessionStore::Session.serializer = :json
      end

      def test_data_column_name
        # default column name is 'data'
        assert_equal 'data', Session.data_column_name
      end

      def test_table_name
        assert_equal 'sessions', Session.table_name
      end

      def test_create_table!
        assert !Session.table_exists?
        Session.create_table!
        assert Session.table_exists?
        Session.drop_table!
        assert !Session.table_exists?
      end

      def test_json_serialization
        Session.create_table!
        ActiveRecord::SessionStore::Session.serializer = :json
        s = session_klass.create!(:data => 'world', :session_id => '7')

        sessions = ActiveRecord::Base.connection.execute("SELECT * FROM #{Session.table_name}")
        data = Session.deserialize(sessions[0][Session.data_column_name])
        assert_equal s.data, data
      end

      def test_hybrid_serialization
        Session.create_table!
        # Star with marshal, which will serialize with Marshal
        ActiveRecord::SessionStore::Session.serializer = :marshal
        s1 = session_klass.create!(:data => 'world', :session_id => '1')

        # Switch to hybrid, which will serialize as JSON
        ActiveRecord::SessionStore::Session.serializer = :hybrid
        s2 = session_klass.create!(:data => 'world', :session_id => '2')

        # Check that first was serialized with Marshal and second as JSON
        sessions = ActiveRecord::Base.connection.execute("SELECT * FROM #{Session.table_name}")
        assert_equal ::Base64.encode64(Marshal.dump(s1.data)), sessions[0][Session.data_column_name]
        assert_equal  s2.data, Session.deserialize(sessions[1][Session.data_column_name])
      end

      def test_hybrid_deserialization
        Session.create_table!
        # Star with marshal, which will serialize with Marshal
        ActiveRecord::SessionStore::Session.serializer = :marshal
        s = session_klass.create!(:data => 'world', :session_id => '1')

        # Switch to hybrid, which will deserialize with Marshal if needed
        ActiveRecord::SessionStore::Session.serializer = :hybrid

        # Check that it was serialized with Marshal,
        sessions = ActiveRecord::Base.connection.execute("SELECT * FROM #{Session.table_name}")
        assert_equal sessions[0][Session.data_column_name], ::Base64.encode64(Marshal.dump(s.data))

        # deserializes properly,
        session = Session.find_by_session_id(s.id)
        assert_equal s.data, session.data

        # and reserializes as JSON
        session.save
        sessions = ActiveRecord::Base.connection.execute("SELECT * FROM #{Session.table_name}")
        assert_equal s.data,Session.deserialize(sessions[0][Session.data_column_name])
      end

      def test_find_by_sess_id_compat
        # Force class reload, as we need to redo the meta-programming
        ActiveRecord::SessionStore.send(:remove_const, :Session)
        load 'active_record/session_store/session.rb'

        Session.reset_column_information
        klass = Class.new(Session) do
          def self.session_id_column
            'sessid'
          end
        end
        klass.create_table!

        assert klass.columns_hash['sessid'], 'sessid column exists'
        session = klass.new(:data => 'hello')
        session.sessid = "100"
        session.save!

        found = klass.find_by_session_id("100")
        assert_equal session, found
        assert_equal session.sessid, found.session_id
      ensure
        klass.drop_table!
        Session.reset_column_information
      end

      def test_find_by_session_id
        Session.create_table!
        session_id = "10"
        s = session_klass.create!(:data => 'world', :session_id => session_id)
        t = session_klass.find_by_session_id(session_id)
        assert_equal s, t
        assert_equal s.data, t.data
        Session.drop_table!
      end

      def test_loaded?
        Session.create_table!
        s = Session.new
        assert !s.loaded?, 'session is not loaded'
      end

      def test_session_can_be_secured
        Session.create_table!
        session_id = 'unsecure'
        session = session_klass.create!(:data => 'world', :session_id => 'foo')
        session.update_column(:session_id, session_id)

        assert_equal 'unsecure', session.read_attribute(:session_id)

        session.secure!

        secured = Rack::Session::SessionId.new(session_id).private_id
        assert_equal secured, session.reload.read_attribute(:session_id)
      end

      def test_session_can_be_secured_with_sessid_compatibility
       # Force class reload, as we need to redo the meta-programming
        ActiveRecord::SessionStore.send(:remove_const, :Session)
        load 'active_record/session_store/session.rb'

        Session.reset_column_information
        klass = Class.new(Session) do
          def self.session_id_column
            'sessid'
          end
        end
        klass.create_table!
        session_id = 'unsecure'
        session = klass.create!(:data => 'world', :sessid => 'foo')
        session.update_column(:sessid, session_id)

        assert_equal 'unsecure', session.read_attribute(:sessid)

        session.secure!

        secured = Rack::Session::SessionId.new(session_id).private_id
        assert_equal secured, session.reload.read_attribute(:sessid)
      ensure
        klass.drop_table!
        Session.reset_column_information
      end

      def test_secure_is_idempotent
        Session.create_table!
        session_id = 'unsecure'
        session = session_klass.create!(:data => 'world', :session_id => 'foo')
        session.update_column(:session_id, session_id)

        assert_equal 'unsecure', session.read_attribute(:session_id)

        session.secure!
        private_id = session.read_attribute(:session_id)
        session.secure!
        session.reload
        session.secure!

        assert_equal private_id, session.reload.read_attribute(:session_id)
      end
    end
  end
end
