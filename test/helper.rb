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

class ActionDispatch::IntegrationTest < ActiveSupport::TestCase
  include ActionDispatch::SharedRoutes

  def self.build_app(routes = nil)
    RoutedRackApp.new(routes || ActionDispatch::Routing::RouteSet.new) do |middleware|
      middleware.use ActionDispatch::DebugExceptions
      middleware.use ActionDispatch::Callbacks
      middleware.use ActionDispatch::Cookies
      middleware.use ActionDispatch::Flash
      middleware.use Rack::Head
      yield(middleware) if block_given?
    end
  end

  private

    def with_test_route_set(options = {})
      controller_namespace = self.class.to_s.underscore

      with_routing do |set|
        set.draw do
          get ':action', :controller => "#{controller_namespace}/test"
        end

        @app = self.class.build_app(set) do |middleware|
          middleware.use ActionDispatch::Session::ActiveRecordStore, options.reverse_merge(:key => '_session_id')
          middleware.delete ActionDispatch::ShowExceptions
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
end

class RoutedRackApp
  attr_reader :routes

  def initialize(routes, &blk)
    @routes = routes
    @stack = ActionDispatch::MiddlewareStack.new(&blk).build(@routes)
  end

  def call(env)
    @stack.call(env)
  end
end

if ActiveSupport::TestCase.respond_to?(:test_order=)
  ActiveSupport::TestCase.test_order = :random
end
