require "bundler/setup"

require "active_record"
require "action_controller"
require "action_dispatch"
require "debug"
require "minitest/autorun"

require "active_record/session_store"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

SharedTestRoutes = ActionDispatch::Routing::RouteSet.new

module ActionDispatch
  module SharedRoutes
    def before_setup
      @routes = SharedTestRoutes
      super
    end
  end
end

class RoutedRackApp
  class Config < Struct.new(:middleware)
  end

  attr_reader :routes

  def initialize(routes, &blk)
    @routes = routes
    @stack = ActionDispatch::MiddlewareStack.new(&blk)
    @app = @stack.build(@routes)
  end

  def call(env)
    @app.call(env)
  end

  def config
    Config.new(@stack)
  end
end

class ActionDispatch::IntegrationTest < ActiveSupport::TestCase
  include ActionDispatch::SharedRoutes

  def self.build_app(routes, options)
    RoutedRackApp.new(routes || ActionDispatch::Routing::RouteSet.new) do |middleware|
      middleware.use ActionDispatch::DebugExceptions
      middleware.use ActionDispatch::ActionableExceptions
      middleware.use ActionDispatch::Callbacks
      middleware.use ActionDispatch::Cookies
      middleware.use ActionDispatch::Flash
      middleware.use Rack::MethodOverride
      middleware.use Rack::Head
      middleware.use ActionDispatch::Session::ActiveRecordStore, options.reverse_merge(key: "_session_id")
      yield(middleware) if block_given?
    end
  end

  self.app = build_app(nil, {})

  private

    def with_test_route_set(options = {})
      controller_namespace = self.class.to_s.underscore
      actions = %w[set_session_value get_session_value call_reset_session renew get_session_id]

      with_routing do |set|
        set.draw do
          actions.each { |action| get action, controller: "#{controller_namespace}/test" }
        end

        self.class.app = self.class.build_app(set, options)

        yield
      end
    end

    def with_store(class_name)
      session_class, ActionDispatch::Session::ActiveRecordStore.session_class =
        ActionDispatch::Session::ActiveRecordStore.session_class, "ActiveRecord::SessionStore::#{class_name.camelize}".constantize
      yield
    ensure
      ActionDispatch::Session::ActiveRecordStore.session_class = session_class
    end
end

ActiveSupport::TestCase.test_order = :random
