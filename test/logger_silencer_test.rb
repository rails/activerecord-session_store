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
      render :text => "foo: #{session[:foo].inspect}"
    end
  end

  def setup
    ActionDispatch::Session::ActiveRecordStore.session_class.drop_table! rescue nil
    ActionDispatch::Session::ActiveRecordStore.session_class.create_table!
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

  private

    def with_fake_logger
      original_logger = ActiveRecord::Base.logger
      ActiveRecord::Base.logger = Logger.new(fake_logger)
      yield
    ensure
      ActiveRecord::Base.logger = original_logger
    end

    def fake_logger
      @fake_logger ||= StringIO.new
    end
end
