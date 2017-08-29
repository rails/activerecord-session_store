require 'helper'
require 'rails/generators/test_case'
require 'active_record/session_store'
require 'generators/active_record/session_migration_generator'

class SessionMigrationGeneratorTest < Rails::Generators::TestCase
  tests ActiveRecord::Generators::SessionMigrationGenerator
  destination 'tmp'
  setup :prepare_destination

  def active_record_migration_class
    active_record_migration_class = ActiveRecord::VERSION::MAJOR < 5 ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  end

  def test_session_migration_with_default_name
    run_generator
    assert_migration "db/migrate/add_sessions_table.rb", /class AddSessionsTable < #{active_record_migration_class}/
  end

  def test_session_migration_with_given_name
    run_generator ["create_session_table"]
    assert_migration "db/migrate/create_session_table.rb", /class CreateSessionTable < #{active_record_migration_class}/
  end

  def test_session_migration_with_custom_table_name
    ActiveRecord::SessionStore::Session.table_name = "custom_table_name"
    run_generator
    assert_migration "db/migrate/add_sessions_table.rb" do |migration|
      assert_match(/class AddSessionsTable < #{active_record_migration_class}/, migration)
      assert_match(/create_table :custom_table_name/, migration)
    end
  ensure
    ActiveRecord::SessionStore::Session.table_name = "sessions"
  end
end
