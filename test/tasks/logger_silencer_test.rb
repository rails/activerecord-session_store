require 'helper'
require 'rake'
require 'stringio'

module ActiveRecord
  module SessionStore
    class LoggerSilencerTest < ActiveSupport::TestCase
      def setup
        Session.drop_table! if Session.table_exists?
        Session.create_table!

        Rake.application.rake_require 'tasks/database'
        Rake::Task.tasks.each(&:reenable)
        Rake::Task.define_task(:environment)
        Rake::Task.define_task('db:load_config')
      end

      def teardown
        Session.drop_table! if Session.table_exists?
        Session.connection.schema_cache.clear!
        Session.reset_column_information
      end

      def test_upgrade_task_does_not_log_sql
        Session.create!(session_id: 'original_session_id', data: 'data')

        with_fake_logger do
          Rake.application.invoke_task 'db:sessions:upgrade'

          assert_no_match(/SELECT/, fake_logger.string)
          assert_no_match(/UPDATE/, fake_logger.string)
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
  end
end
