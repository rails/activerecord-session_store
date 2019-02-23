module ActionDispatch
  module Session
    module LegacySupport
      EnvWrapper = Struct.new(:env)

      def self.included(klass)
        [
          :get_session,
          :get_session_model,
          :write_session,
          :delete_session,
          :find_session,
          :extract_session_id,
          :unpacked_cookie_data,
          :set_cookie,
          :get_cookie,
          :cookie_jar
        ].each do |m|
          klass.send(:alias_method, "#{m}_rails5".to_sym, m)
          klass.send(:remove_method, m)
        end
      end

      def get_session(env, sid)
        request = EnvWrapper.new(env)
        get_session_rails5(request, sid)
      end

      def set_session(env, sid, session_data, options)
        request = EnvWrapper.new(env)
        write_session_rails5(request, sid, session_data, options)
      end

      def destroy_session(env, session_id, options)
        request = EnvWrapper.new(env)
        if sid = current_session_id(request.env)
          get_session_model(request, sid).destroy
          request.env[self.class::SESSION_RECORD_KEY] = nil
        end
        generate_sid unless options[:drop]
      end

      def get_session_model(request, sid)
        if request.env[self.class::ENV_SESSION_OPTIONS_KEY][:id].nil?
          request.env[self.class::SESSION_RECORD_KEY] = find_session(sid)
        else
          request.env[self.class::SESSION_RECORD_KEY] ||= find_session(sid)
        end
      end

      def find_session(id)
        self.class.session_class.find_by_session_id(id) || self.class.session_class.new(:session_id => id, :data => {})
      end

      # Inspired by Rails 4 ActionDispatch::Session::CookieStore
      # https://github.com/rails/rails/blob/6b9a1ac484a4eda1b43aba7ed864952aac743ab9/actionpack/lib/action_dispatch/middleware/session/cookie_store.rb
      def extract_session_id(env)
        sid = stale_session_check! do
          unpacked_cookie_data(env)
        end

        sid ||= env["action_dispatch.request.parameters"][@key] unless @cookie_only
        sid
      end

      # Inspired by Rails 4 ActionDispatch::Session::CookieStore
      # https://github.com/rails/rails/blob/6b9a1ac484a4eda1b43aba7ed864952aac743ab9/actionpack/lib/action_dispatch/middleware/session/cookie_store.rb
      def unpacked_cookie_data(env)
        env["action_dispatch.request.unsigned_session_cookie"] ||= begin
          stale_session_check! do
            get_cookie(env) || nil  # not empty string
          end
        end
      end

      # https://github.com/rails/rails/blob/6b9a1ac484a4eda1b43aba7ed864952aac743ab9/actionpack/lib/action_dispatch/middleware/session/cookie_store.rb
      def set_cookie(env, session_id, cookie)
        cookie_jar(env)[@key] = cookie
      end

      # https://github.com/rails/rails/blob/6b9a1ac484a4eda1b43aba7ed864952aac743ab9/actionpack/lib/action_dispatch/middleware/session/cookie_store.rb
      def get_cookie(env)
        cookie_jar(env)[@key]
      end

      # Inspired by Rails 4 ActionDispatch::Session::CookieStore
      # https://github.com/rails/rails/blob/6b9a1ac484a4eda1b43aba7ed864952aac743ab9/actionpack/lib/action_dispatch/middleware/session/cookie_store.rb
      def cookie_jar(env)
        request = ActionDispatch::Request.new(env)
        if cookie_is_signed_or_encrypted?
          request.cookie_jar.signed_or_encrypted
        else
          request.cookie_jar
        end
      end

    end
  end
end

