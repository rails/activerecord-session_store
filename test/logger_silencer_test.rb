require 'helper'
require "stringio"

class LoggerSilencerTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def set_session_value
      raise "missing session!" unless session
      session[:foo] = params[:foo] || "bar"
      head :ok
    end

    def get_session_value
      render :plain => "foo: #{session[:foo].inspect}"
    end
  end

  def setup
    session_class = ActiveRecord::SessionStore::Session
    session_class.drop_table! rescue nil
    session_class.create_table!
    ActionDispatch::Session::ActiveRecordStore.session_class = session_class
  end

  %w{ session sql_bypass }.each do |class_name|
    define_method("test_#{class_name}_store_does_not_log_sql") do
      with_store class_name do
        with_fake_logger do
          with_test_route_set do
            get "/set_session_value"
            get "/get_session_value"
            assert_no_match(/INSERT/, fake_logger.string)
            assert_no_match(/SELECT/, fake_logger.string)
          end
        end
      end
    end
  end

  def test_log_silencer_with_logger_not_raise_exception
    with_logger ActiveSupport::Logger.new(Tempfile.new("tempfile")) do
      with_test_route_set do
        assert_nothing_raised do
          get "/set_session_value"
        end
      end
    end
  end

  private

    def with_logger(logger)
      original_logger = ActiveRecord::Base.logger
      ActiveRecord::Base.logger = logger
      yield
    ensure
      ActiveRecord::Base.logger = original_logger
    end

    def with_fake_logger(&block)
      with_logger(ActiveSupport::Logger.new(fake_logger), &block)
    end

    def fake_logger
      @fake_logger ||= StringIO.new
    end
end
