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

Then, set your session store in `config/initializers/session_store.rb`:

```ruby
Rails.application.config.session_store :active_record_store, :key => '_my_app_session'
```

Configuration
--------------

The default assumes a `sessions` tables with columns:

*  `id` (numeric primary key),
*  `session_id` (string, usually varchar; maximum length is 255), and
*  `data` (text or longtext; careful if your session data exceeds 65KB).

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

The serializer may be one of `marshal`, `json`, or `hybrid`.  `marshal` is
the default and uses the built-in Marshal methods coupled with Base64
encoding.  `json` does what it says on the tin, using the `parse()` and
`generate()` methods of the JSON module.  `hybrid` will read either type
but write as JSON.

Since the default class is a simple Active Record, you get timestamps
for free if you add `created_at` and `updated_at` datetime columns to
the `sessions` table, making periodic session expiration a snap.

You may provide your own session class implementation, whether a
feature-packed Active Record or a bare-metal high-performance SQL
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
custom logger if you are using a logger other than `Logger` and `Syslog::Logger`
and their subclasses:

```ruby
MyLogger.send :include, ActiveRecord::SessionStore::Extension::LoggerSilencer
```

This silencer is being used to silence the logger and not leaking private
information into the log, and it is required for security reason.

## Contributing to Active Record Session Store

Active Record Session Store is work of many contributors. You're encouraged to submit pull requests, propose features and discuss issues.

See [CONTRIBUTING](CONTRIBUTING.md).

## License
Active Record Session Store is released under the [MIT License](MIT-LICENSE).
