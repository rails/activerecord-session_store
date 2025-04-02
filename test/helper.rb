require 'bundler/setup'

require 'active_record'
require 'action_controller'
require 'action_dispatch'
require 'minitest/autorun'

require 'active_record/session_store'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

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

  def self.build_app(routes = nil)
    RoutedRackApp.new(routes || ActionDispatch::Routing::RouteSet.new) do |middleware|
      middleware.use ActionDispatch::DebugExceptions
      middleware.use ActionDispatch::ActionableExceptions
      middleware.use ActionDispatch::Callbacks
      middleware.use ActionDispatch::Cookies
      middleware.use ActionDispatch::Flash
      middleware.use Rack::MethodOverride
      middleware.use Rack::Head
      yield(middleware) if block_given?
    end
  end

  self.app = build_app

  private

    def session_options(options = {})
      (@session_options ||= {key: "_session_id"}).merge!(options)
    end

    def app
      @app ||= self.class.build_app do |middleware|
        middleware.use ActionDispatch::Session::ActiveRecordStore, session_options
      end
    end

    def with_test_route_set
      controller_namespace = self.class.to_s.underscore
      actions = %w[set_session_value get_session_value call_reset_session renew get_session_id]

      with_routing do |set|
        set.draw do
          actions.each { |action| get action, controller: "#{controller_namespace}/test" }
        end

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

  # Patch in support for with_routing for integration tests, which was introduced in Rails 7.2
  if !defined?(ActionDispatch::Assertions::RoutingAssertions::WithIntegrationRouting)
    require_relative 'with_integration_routing_patch'

    include WithIntegrationRoutingPatch
  end
end

ActiveSupport::TestCase.test_order = :random
