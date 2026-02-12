require 'rails/railtie'

module ActiveRecord
  module SessionStore
    class Railtie < Rails::Railtie
      rake_tasks { load File.expand_path("../../../tasks/database.rake", __FILE__) }

      initializer "activerecord-session_store.deprecator" do |app|
        app.deprecators[:"activerecord-session_store"] = SessionStore.deprecator
      end
    end
  end
end
