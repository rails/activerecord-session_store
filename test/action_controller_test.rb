require 'helper'

class ActionControllerTest < ActionDispatch::IntegrationTest
  SessionKey    = "_session_id"
  SessionSecret = "b3c631c314c0bbca50c1b2843150fe33"
  SessionSalt   = "signed or encrypted cookie"

  if ActiveRecord::VERSION::MAJOR == 4
    Generator = ActiveSupport::KeyGenerator.new(SessionSecret)

    Verifier = ActiveSupport::MessageVerifier.new(Generator.generate_key(SessionSalt), :digest => 'SHA1')

    Encryptor = ActiveSupport::MessageEncryptor.new(Generator.generate_key(SessionSalt, 32), Generator.generate_key(SessionSalt))

  else
    Generator = ActiveSupport::KeyGenerator.new(SessionSecret, iterations: 1000)
    Rotations = ActiveSupport::Messages::RotationConfiguration.new

    Verifier = ActiveSupport::MessageVerifier.new(
      Generator.generate_key(SessionSalt), serializer: Marshal
    )

    Encryptor = ActiveSupport::MessageEncryptor.new(
      Generator.generate_key(SessionSalt, 32), cipher: "aes-256-gcm", serializer: Marshal
    )
  end

  class TestController < ActionController::Base
    protect_from_forgery
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
      head :ok
    end
  end

  def setup
    ActionDispatch::Session::ActiveRecordStore.session_class.drop_table! rescue nil
    ActionDispatch::Session::ActiveRecordStore.session_class.create_table!

    ActiveRecord::SessionStore::Session.sign_cookie = false
    ActiveRecord::SessionStore::Session.encrypt_cookie = false
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

  def test_signed_cookie
    ActiveRecord::SessionStore::Session.sign_cookie = true
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']
      session_id_signed = cookies['_session_id']

      if ActiveRecord::VERSION::MAJOR == 4
        session_id, time = Verifier.verify(session_id_signed) rescue nil
        time = time  # Suppress "warning: assigned but unused variable - time"
      else
        session_id = Verifier.verified(session_id_signed) rescue nil
      end

      get '/get_session_id'
      assert_response :success
      assert_equal session_id, response.body, "should be able to read signed session id"
    end
  end

  def test_encrypted_cookie
    ActiveRecord::SessionStore::Session.encrypt_cookie = true
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']
      session_id_encrypted = cookies['_session_id']
      session_id = Encryptor.decrypt_and_verify(session_id_encrypted) rescue nil

      get '/get_session_id'
      assert_response :success
      assert_equal session_id, response.body, "should be able to read encrypted session id"
    end
  end

  # From https://github.com/rails/rails/blob/master/actionpack/test/dispatch/session/cookie_store_test.rb
  def test_signed_cookie_disregards_tampered_sessions
    ActiveRecord::SessionStore::Session.sign_cookie = true
    with_test_route_set do
      bad_key = Generator.generate_key(SessionSalt).reverse

      if ActiveRecord::VERSION::MAJOR == 4
        verifier = ActiveSupport::MessageVerifier.new(bad_key, :digest => 'SHA1')
      else
        verifier = ActiveSupport::MessageVerifier.new(bad_key, serializer: Marshal)
      end

      cookies[SessionKey] = verifier.generate("foo" => "bar", "session_id" => "abc")

      get "/get_session_value"

      assert_response :success
      assert_equal "foo: nil", response.body
    end
  end

  # From https://github.com/rails/rails/blob/master/actionpack/test/dispatch/session/cookie_store_test.rb
  def test_encrypted_cookie_disregards_tampered_sessions
    ActiveRecord::SessionStore::Session.encrypt_cookie = true
    with_test_route_set do

      if ActiveRecord::VERSION::MAJOR == 4
        bad_sign_secret = Generator.generate_key(SessionSalt).reverse
        encryptor = ActiveSupport::MessageEncryptor.new(Generator.generate_key(SessionSalt, 32), bad_sign_secret)
      else
        encryptor = ActiveSupport::MessageEncryptor.new("A" * 32, cipher: "aes-256-gcm", serializer: Marshal)
      end

      cookies[SessionKey] = encryptor.encrypt_and_sign("foo" => "bar", "session_id" => "abc")

      get "/get_session_value"

      assert_response :success
      assert_equal "foo: nil", response.body
    end
  end

  def test_doesnt_write_session_cookie_if_session_id_is_already_exists
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']

      get '/get_session_value'
      assert_response :success
      assert_nil headers['Set-Cookie'], "should not resend the cookie again if session_id cookie is already exists"
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

  private

    if ActiveRecord::VERSION::MAJOR == 4
      # Overwrite get to send SessionSecret in env hash
      # Inspired by https://github.com/rails/rails/blob/6b9a1ac484a4eda1b43aba7ed864952aac743ab9/actionpack/test/dispatch/session/cookie_store_test.rb
      def get(path, parameters = nil, env = {})
        signed = ActiveRecord::SessionStore::Session.sign_cookie
        encrypted = ActiveRecord::SessionStore::Session.encrypt_cookie

        if signed || encrypted
          env["action_dispatch.key_generator"] ||= Generator
        end

        if signed && ! encrypted
          env["action_dispatch.signed_cookie_salt"] = SessionSalt

        elsif encrypted
          env["action_dispatch.encrypted_cookie_salt"] = SessionSalt
          env["action_dispatch.encrypted_signed_cookie_salt"] = SessionSalt
          env["action_dispatch.secret_key_base"] = SessionSecret
        end

        super
      end

    else
      # Overwrite get to send SessionSecret in env hash
      # Inspired by https://github.com/rails/rails/blob/master/actionpack/test/dispatch/session/cookie_store_test.rb
      def get(path, *args)
        args[0] ||= {}
        args[0][:headers] ||= {}
        args[0][:headers].tap do |config|
          signed = ActiveRecord::SessionStore::Session.sign_cookie
          encrypted = ActiveRecord::SessionStore::Session.encrypt_cookie

          if signed || encrypted
            config["action_dispatch.key_generator"] ||= Generator
            config["action_dispatch.cookies_rotations"] ||= Rotations unless ActiveRecord::VERSION::MAJOR == 4
          end

          if signed && ! encrypted
            config["action_dispatch.signed_cookie_salt"] = SessionSalt

          elsif encrypted
            config["action_dispatch.authenticated_encrypted_cookie_salt"] = SessionSalt
            config["action_dispatch.secret_key_base"] = SessionSecret
            config["action_dispatch.use_authenticated_cookie_encryption"] = true
          end

        end

        super(path, *args)
      end
    end

end
