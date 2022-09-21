require 'helper'

class ActionControllerTest < ActionDispatch::IntegrationTest
  SessionKey    = "_session_id"
  SessionSecret = "b3c631c314c0bbca50c1b2843150fe33"
  SessionSalt   = "signed or encrypted cookie"

  Generator = ActiveSupport::KeyGenerator.new(SessionSecret, iterations: 1000)
  Rotations = ActiveSupport::Messages::RotationConfiguration.new

  Verifier = ActiveSupport::MessageVerifier.new(
    Generator.generate_key(SessionSalt), serializer: Marshal
  )

  Cipher = "aes-256-gcm"

  Encryptor = ActiveSupport::MessageEncryptor.new(
    Generator.generate_key(SessionSalt, 32), cipher: Cipher, serializer: Marshal
  )

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
      render :plain => "foo: #{session[:foo].inspect}"
    end

    def get_session_id
      render :plain => "#{request.session['session_id']}"
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

          get '/set_session_value', :params => { :foo => "baz" }
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
      get '/call_reset_session', :params => { :twice => "true" }
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

      session_id = Verifier.verified(session_id_signed) rescue nil

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

  # From https://github.com/rails/rails/blob/main/actionpack/test/dispatch/session/cookie_store_test.rb
  def test_signed_cookie_disregards_tampered_sessions
    ActiveRecord::SessionStore::Session.sign_cookie = true
    with_test_route_set do
      bad_key = Generator.generate_key(SessionSalt).reverse

      verifier = ActiveSupport::MessageVerifier.new(bad_key, serializer: Marshal)

      cookies[SessionKey] = verifier.generate({ "foo" => "bar", "session_id" => "abc" })

      get "/get_session_value"

      assert_response :success
      assert_equal "foo: nil", response.body
    end
  end

  # From https://github.com/rails/rails/blob/main/actionpack/test/dispatch/session/cookie_store_test.rb
  def test_encrypted_cookie_disregards_tampered_sessions
    ActiveRecord::SessionStore::Session.encrypt_cookie = true
    with_test_route_set do

      encryptor = ActiveSupport::MessageEncryptor.new("A" * 32, cipher: Cipher, serializer: Marshal)

      cookies[SessionKey] = encryptor.encrypt_and_sign({ "foo" => "bar", "session_id" => "abc" })

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

      get '/get_session_value', :params => { :_session_id => session_id }
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

      get '/set_session_value', :params => { :_session_id => session_id, :foo => "baz" }
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
        sess.get '/set_session_value', :params => { :_session_id => 'INVALID' }
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

  %w{ session sql_bypass }.each do |class_name|
    define_method :"test_sessions_are_indexed_by_a_hashed_session_id_for_#{class_name}" do
      with_store(class_name) do
        with_test_route_set do
          get '/set_session_value'
          assert_response :success
          public_session_id = cookies['_session_id']

          session = ActiveRecord::SessionStore::Session.last
          assert session
          assert_not_equal public_session_id, session.session_id

          expected_private_id = Rack::Session::SessionId.new(public_session_id).private_id

          assert_equal expected_private_id, session.session_id
        end
      end
    end

    define_method :"test_unsecured_sessions_are_retrieved_and_migrated_for_#{class_name}" do
      with_store(class_name) do
        with_test_route_set do
          get '/set_session_value', params: { foo: 'baz' }
          assert_response :success
          public_session_id = cookies['_session_id']

          session = ActiveRecord::SessionStore::Session.last
          session.data # otherwise we cannot save
          session.session_id = public_session_id
          session.save!

          get '/get_session_value'
          assert_response :success
          assert_equal 'foo: "baz"', response.body

          session = ActiveRecord::SessionStore::Session.last
          assert_not_equal public_session_id, session.read_attribute(:session_id)
        end
      end
    end

    # to avoid a different kind of timing attack
    define_method :"test_sessions_cannot_be_retrieved_by_their_private_session_id_for_#{class_name}" do
      with_store(class_name) do
        with_test_route_set do
          get '/set_session_value', params: { foo: 'baz' }
          assert_response :success

          session = ActiveRecord::SessionStore::Session.last
          private_session_id = session.read_attribute(:session_id)

          cookies.merge("_session_id=#{private_session_id};path=/")

          get '/get_session_value'
          assert_response :success
          assert_equal 'foo: nil', response.body
        end
      end
    end
  end

  private

    # Overwrite get to send SessionSecret in env hash
    # Inspired by https://github.com/rails/rails/blob/main/actionpack/test/dispatch/session/cookie_store_test.rb
    def get(path, **options)
      options[:headers] ||= {}
      options[:headers].tap do |config|
        signed = ActiveRecord::SessionStore::Session.sign_cookie
        encrypted = ActiveRecord::SessionStore::Session.encrypt_cookie
        aead_mode = (Cipher == "aes-256-gcm")

        if signed || encrypted
          config["action_dispatch.key_generator"] ||= Generator
          config["action_dispatch.cookies_rotations"] ||= Rotations
        end

        if signed && ! encrypted
          config["action_dispatch.signed_cookie_salt"] = SessionSalt

        elsif encrypted
          config["action_dispatch.secret_key_base"] = SessionSecret

          config["action_dispatch.encrypted_cookie_cipher"] = Cipher

          if aead_mode
            config["action_dispatch.authenticated_encrypted_cookie_salt"] = SessionSalt
            config["action_dispatch.use_authenticated_cookie_encryption"] = true

          else
            config["action_dispatch.encrypted_cookie_salt"] = SessionSalt
            config["action_dispatch.encrypted_signed_cookie_salt"] = SessionSalt
            config["action_dispatch.use_authenticated_cookie_encryption"] = false
          end
        end

      end

      super
    end

end
