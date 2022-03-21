Active Record Session Store
===========================

A session store backed by an Active Record class. A default class is
provided, but any object duck-typing to an Active Record Session class
with text `session_id` and `data` attributes is sufficient.

Installation
------------

Include this gem into your Gemfile:

```ruby
gem 'activerecord-session_store'
```

Run the migration generator:

    rails generate active_record:session_migration

Run the migration:

    rake db:migrate

Then, set your session store in `config/initializers/session_store.rb`:

```ruby
Rails.application.config.session_store :active_record_store, :key => '_my_app_session'
```

To avoid your sessions table expanding without limit as it will store expired and
potentially sensitive session data, it is strongly recommended in production
environments to schedule the `db:sessions:trim` rake task to run daily.
Running `bin/rake db:sessions:trim` will delete all sessions that have not
been updated in the last 30 days. The 30 days cutoff can be changed using the
`SESSION_DAYS_TRIM_THRESHOLD` environment variable.

Configuration
--------------

The default assumes a `sessions` table with columns:

*  `id` (numeric primary key),
*  `session_id` (string, usually varchar; maximum length is 255), and
*  `data` (text, longtext, json or jsonb); careful if your session data exceeds
65KB).

The `session_id` column should always be indexed for speedy lookups.
Session data is marshaled to the `data` column in Base64 format.
If the data you write is larger than the column's size limit,
ActionController::SessionOverflowError will be raised.

You may configure the table name, primary key, data column, and
serializer type. For example, at the end of `config/application.rb`:

```ruby
ActiveRecord::SessionStore::Session.table_name = 'legacy_session_table'
ActiveRecord::SessionStore::Session.primary_key = 'session_id'
ActiveRecord::SessionStore::Session.data_column_name = 'legacy_session_data'
ActiveRecord::SessionStore::Session.serializer = :json
```

Note that setting the primary key to the `session_id` frees you from
having a separate `id` column if you don't want it. However, you must
set `session.model.id = session.session_id` by hand!  A before filter
on ApplicationController is a good place.

The serializer may be class responding to `#load(value)` and `#dump(value)`, or
a symbol of `marshal`, `json`, `hybrid` or `null`. `marshal` is the default and
uses the built-in Marshal methods coupled with Base64 encoding. `json` does
what it says on the tin, using the `parse()` and `generate()` methods of the
JSON module. `hybrid` will read either type but write as JSON. `null` will
not perform serialization, leaving that up to the ActiveRecord database
adapter. This allows you to take advantage of the native JSON capabilities of
your database.

Since the default class is a simple Active Record, you get timestamps
for free if you add `created_at` and `updated_at` datetime columns to
the `sessions` table, making periodic session expiration a snap.

You may provide your own session class implementation, whether a
feature-packed Active Record, or a bare-metal high-performance SQL
store, by setting

```ruby
ActionDispatch::Session::ActiveRecordStore.session_class = MySessionClass
```

You must implement these methods:

* `self.find_by_session_id(session_id)`
* `initialize(hash_of_session_id_and_data, options_hash = {})`
* `attr_reader :session_id`
* `attr_accessor :data`
* `save`
* `destroy`

The example SqlBypass class is a generic SQL session store. You may
use it as a basis for high-performance database-specific stores.

Please note that you will need to manually include the silencer module to your
custom logger if you are using a logger other than `ActiveSupport::Logger` and
its subclasses:

```ruby
MyLogger.include ActiveSupport::LoggerSilence
```

Or if you are using Rails 5.2 or older:

```ruby
MyLogger.include ::LoggerSilence
```

This silencer is being used to silence the logger and not leaking private
information into the log, and it is required for security reason.

CVE-2019-25025 mitigation
--------------

Sessions that were created by Active Record Session Store version 1.x are
affected by [CVE-2019-25025]. This means an attacker can perform a timing
attack against the session IDs stored in the database.

[CVE-2019-25025]: https://github.com/advisories/GHSA-cvw2-xj8r-mjf7

After upgrade to version 2.0.0, you should run [`db:sessions:upgrade`] rake task
to upgrade all existing session records in your database to the secured version.

[`db:sessions:upgrade`]: https://github.com/rails/activerecord-session_store/blob/master/lib/tasks/database.rake#L22

```console
$ rake db:sessions:upgrade
```

This rake task is idempotent and can be run multiple times, and session data of
users will remain intact.

Please see [#151] for more details.

[#151]: https://github.com/rails/activerecord-session_store/pull/151

Contributing to Active Record Session Store
--------------

Active Record Session Store is work of many contributors. You're encouraged to submit pull requests, propose features and discuss issues.

See [CONTRIBUTING](CONTRIBUTING.md).

## License
Active Record Session Store is released under the [MIT License](MIT-LICENSE).
