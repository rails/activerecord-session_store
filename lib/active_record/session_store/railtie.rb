require 'rails/railtie'

module ActiveRecord
  module SessionStore
    class Railtie < Rails::Railtie
      rake_tasks { load "tasks/database.rake" }
    end
  end
end
