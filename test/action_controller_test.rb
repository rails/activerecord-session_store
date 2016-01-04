require 'helper'

class ActionControllerTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def no_session_access
      head :ok
    end

    def set_session_value
      raise "missing session!" unless session
      session[:foo] = params[:foo] || "bar"
      head :ok
    end

    def get_session_value
      if ActiveRecord::VERSION::MAJOR == 4
        render :text => "foo: #{session[:foo].inspect}"
      else
        render :plain => "foo: #{session[:foo].inspect}"
      end
    end

    def get_session_id
      if ActiveRecord::VERSION::MAJOR == 4
        render :text => "#{request.session.id}"
      else
        render :plain => "#{request.session.id}"
      end
    end

    def call_reset_session
      session[:foo]
      reset_session
      reset_session if params[:twice]
      session[:foo] = "baz"
      head :ok
    end

    def renew
      request.env["rack.session.options"][:renew] = true
      session[:foo] = "baz"
      head :ok
    end
  end

  def setup
    ActionDispatch::Session::ActiveRecordStore.session_class.drop_table! rescue nil
    ActionDispatch::Session::ActiveRecordStore.session_class.create_table!
  end

  %w{ session sql_bypass }.each do |class_name|
    define_method("test_setting_and_getting_session_value_with_#{class_name}_store") do
      with_store class_name do
        with_test_route_set do
          get '/set_session_value'
          assert_response :success
          assert cookies['_session_id']

          get '/get_session_value'
          assert_response :success
          assert_equal 'foo: "bar"', response.body

          if ActiveRecord::VERSION::MAJOR == 4
            get '/set_session_value', :foo => "baz"
          else
            get '/set_session_value', :params => { :foo => "baz" }
          end
          assert_response :success
          assert cookies['_session_id']

          get '/get_session_value'
          assert_response :success
          assert_equal 'foo: "baz"', response.body

          get '/call_reset_session'
          assert_response :success
          assert_not_equal [], headers['Set-Cookie']
        end
      end
    end

    define_method("test_renewing_with_#{class_name}_store") do
      with_store class_name do
        with_test_route_set do
          get '/set_session_value'
          assert_response :success
          assert cookies['_session_id']

          get '/renew'
          assert_response :success
          assert_not_equal [], headers['Set-Cookie']
        end
      end
    end
  end

  def test_getting_nil_session_value
    with_test_route_set do
      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: nil', response.body
    end
  end

  def test_calling_reset_session_twice_does_not_raise_errors
    with_test_route_set do
      if ActiveRecord::VERSION::MAJOR == 4
        get '/call_reset_session', :twice => "true"
      else
        get '/call_reset_session', :params => { :twice => "true" }
      end
      assert_response :success

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: "baz"', response.body
    end
  end

  def test_setting_session_value_after_session_reset
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']
      session_id = cookies['_session_id']

      get '/call_reset_session'
      assert_response :success
      assert_not_equal [], headers['Set-Cookie']

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: "baz"', response.body

      get '/get_session_id'
      assert_response :success
      assert_not_equal session_id, response.body
    end
  end

  def test_getting_session_value_after_session_reset
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']
      session_cookie = cookies.send(:hash_for)['_session_id']

      get '/call_reset_session'
      assert_response :success
      assert_not_equal [], headers['Set-Cookie']

      cookies << session_cookie # replace our new session_id with our old, pre-reset session_id

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: nil', response.body, "data for this session should have been obliterated from the database"
    end
  end

  def test_getting_from_nonexistent_session
    with_test_route_set do
      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: nil', response.body
      assert_nil cookies['_session_id'], "should only create session on write, not read"
    end
  end

  def test_getting_session_id
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']
      session_id = cookies['_session_id']

      get '/get_session_id'
      assert_response :success
      assert_equal session_id, response.body, "should be able to read session id without accessing the session hash"
    end
  end

  def test_doesnt_write_session_cookie_if_session_id_is_already_exists
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']

      get '/get_session_value'
      assert_response :success
      assert_equal nil, headers['Set-Cookie'], "should not resend the cookie again if session_id cookie is already exists"
    end
  end

  def test_prevents_session_fixation
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: "bar"', response.body
      session_id = cookies['_session_id']
      assert session_id

      reset!

      if ActiveRecord::VERSION::MAJOR == 4
        get '/get_session_value', :_session_id => session_id
      else
        get '/get_session_value', :params => { :_session_id => session_id }
      end
      assert_response :success
      assert_equal 'foo: nil', response.body
      assert_not_equal session_id, cookies['_session_id']
    end
  end

  def test_allows_session_fixation
    with_test_route_set(:cookie_only => false) do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: "bar"', response.body
      session_id = cookies['_session_id']
      assert session_id

      reset!

      if ActiveRecord::VERSION::MAJOR == 4
        get '/set_session_value', :_session_id => session_id, :foo => "baz"
      else
        get '/set_session_value', :params => { :_session_id => session_id, :foo => "baz" }
      end
      assert_response :success
      assert_equal session_id, cookies['_session_id']

      get '/get_session_value', :params => { :_session_id => session_id }
      assert_response :success
      assert_equal 'foo: "baz"', response.body
      assert_equal session_id, cookies['_session_id']
    end
  end

  def test_incoming_invalid_session_id_via_cookie_should_be_ignored
    with_test_route_set do
      open_session do |sess|
        sess.cookies['_session_id'] = 'INVALID'

        sess.get '/set_session_value'
        new_session_id = sess.cookies['_session_id']
        assert_not_equal 'INVALID', new_session_id

        sess.get '/get_session_value'
        new_session_id_2 = sess.cookies['_session_id']
        assert_equal new_session_id, new_session_id_2
      end
    end
  end

  def test_incoming_invalid_session_id_via_parameter_should_be_ignored
    with_test_route_set(:cookie_only => false) do
      open_session do |sess|
        if ActiveRecord::VERSION::MAJOR == 4
          sess.get '/set_session_value', :_session_id => 'INVALID'
        else
          sess.get '/set_session_value', :params => { :_session_id => 'INVALID' }
        end
        new_session_id = sess.cookies['_session_id']
        assert_not_equal 'INVALID', new_session_id

        sess.get '/get_session_value'
        new_session_id_2 = sess.cookies['_session_id']
        assert_equal new_session_id, new_session_id_2
      end
    end
  end

  def test_session_store_with_all_domains
    with_test_route_set(:domain => :all) do
      get '/set_session_value'
      assert_response :success
    end
  end
end
