require 'helper'
require 'rake'

module ActiveRecord
  module SessionStore
    class DatabaseRakeTest < ActiveSupport::TestCase
      class AddTimestampsToSession < ActiveRecord::Migration
        self.verbose = false

        def change
          add_column Session.table_name, :created_at, :datetime
          add_column Session.table_name, :updated_at, :datetime
        end
      end

      def setup
        Session.drop_table! if Session.table_exists?
        Session.create_table!

        AddTimestampsToSession.new.exec_migration(ActiveRecord::Base.connection, :up)
        Session.connection.schema_cache.clear!
        Session.reset_column_information

        Rake.application.rake_require "tasks/database"
        Rake::Task.define_task(:environment)
        Rake::Task.define_task("db:load_config")
      end

      def teardown
        Session.drop_table! if Session.table_exists?
        Session.connection.schema_cache.clear!
        Session.reset_column_information
      end

      def test_trim_task
        cutoff_period = 30.days.ago

        Session.create!(data: "obsolete") do |session|
          session.updated_at = 5.minutes.until(cutoff_period)
        end

        recent_session = Session.create!(data: "recent") do |session|
          session.updated_at = 5.minutes.since(cutoff_period)
        end

        Rake.application.invoke_task 'db:sessions:trim'

        old_session_count = Session.where("updated_at < ?", cutoff_period).count
        retained_session = Session.find(recent_session.id)

        assert_equal 0, old_session_count
        assert_equal retained_session, recent_session
      end
    end
  end
end
