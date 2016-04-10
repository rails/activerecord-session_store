if ActiveRecord::VERSION::MAJOR > 4

  require 'action_dispatch/middleware/session/abstract_store'

  module ActionDispatch
    class Request
      class DestroySessionTest < ActiveSupport::TestCase
        attr_reader :req

        def setup
          @req = ActionDispatch::Request.empty
          ActionDispatch::Session::ActiveRecordStore.session_class.drop_table! rescue nil
          ActionDispatch::Session::ActiveRecordStore.session_class.create_table!
        end

        def record_key
          ActionDispatch::Session::ActiveRecordStore::SESSION_RECORD_KEY
        end

        def test_destroy_without_renew
          s = Session.create(store, req, { :renew => false })
          s['set_something_so_it_loads'] = true

          session_model = req.env[record_key]
          session_model.update_attributes(:data => {'rails' => 'ftw'})

          s.destroy

          renewed_session_model = req.env[record_key]
          assert_equal nil, renewed_session_model.data['rails']
        end

        def test_destroy_with_renew
          s = Session.create(store, req, { :renew => true })
          s['set_something_so_it_loads'] = true

          session_model = req.env[record_key]
          session_model.update_attributes(:data => {'rails' => 'ftw'})

          s.destroy

          renewed_session_model = req.env[record_key]
          assert_equal 'ftw', renewed_session_model.data['rails']
        end

        private
        def store
          ActionDispatch::Session::ActiveRecordStore.new(req.env, {})
        end
      end
    end
  end
end