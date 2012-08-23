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
      middleware.use "ActionDispatch::DebugExceptions"
      middleware.use "ActionDispatch::Callbacks"
      middleware.use "ActionDispatch::ParamsParser"
      middleware.use "ActionDispatch::Cookies"
      middleware.use "ActionDispatch::Flash"
      middleware.use "Rack::Head"
      yield(middleware) if block_given?
    end
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
