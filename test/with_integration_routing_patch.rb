# Bring with_routing method support for integration tests back to Rails 7.1.
# We can remove this when we drop support for Rails 7.1.
# See: https://github.com/rails/rails/pull/49819
module WithIntegrationRoutingPatch # :nodoc:
  extend ActiveSupport::Concern

  module ClassMethods
    def with_routing(&block)
      old_routes = nil
      old_routes_call_method = nil
      old_integration_session = nil

      setup do
        old_routes = app.routes
        old_routes_call_method = old_routes.method(:call)
        old_integration_session = integration_session
        create_routes(&block)
      end

      teardown do
        reset_routes(old_routes, old_routes_call_method, old_integration_session)
      end
    end
  end

  def with_routing(&block)
    old_routes = app.routes
    old_routes_call_method = old_routes.method(:call)
    old_integration_session = integration_session
    create_routes(&block)
  ensure
    reset_routes(old_routes, old_routes_call_method, old_integration_session)
  end

  private

  def create_routes
    app = self.app
    routes = ActionDispatch::Routing::RouteSet.new

    @original_routes ||= app.routes
    @original_routes.singleton_class.redefine_method(:call, &routes.method(:call))

    https = integration_session.https?
    host = integration_session.host

    app.instance_variable_set(:@routes, routes)

    @integration_session = Class.new(ActionDispatch::Integration::Session) do
      include app.routes.url_helpers
      include app.routes.mounted_helpers
    end.new(app)
    @integration_session.https! https
    @integration_session.host! host
    @routes = routes

    yield routes
  end

  def reset_routes(old_routes, old_routes_call_method, old_integration_session)
    app.instance_variable_set(:@routes, old_routes)
    @original_routes.singleton_class.redefine_method(:call, &old_routes_call_method)
    @integration_session = old_integration_session
    @routes = old_routes
  end
end
