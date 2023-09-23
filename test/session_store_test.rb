require "helper"
require "action_dispatch/session/active_record_store"

module ActionDispatch
  module Session
    class ActiveRecordStoreTest < ActiveSupport::TestCase

      class Session < ActiveRecord::SessionStore::Session; end

      def test_session_class_as_string
        with_session_class("ActionDispatch::Session::ActiveRecordStoreTest::Session") do
          assert_equal(Session, ActiveRecordStore.session_class)
        end
      end

      def test_session_class_as_proc
        with_session_class(proc { Session }) do
          assert_equal(Session, ActiveRecordStore.session_class)
        end
      end

      def test_session_class_as_class
        with_session_class(Session) do
          assert_equal(Session, ActiveRecordStore.session_class)
        end
      end

      private

      def with_session_class(klass)
        old_klass = ActiveRecordStore.session_class
        ActiveRecordStore.session_class = klass
        yield
      ensure
        ActiveRecordStore.session_class = old_klass
      end
    end
  end
end
