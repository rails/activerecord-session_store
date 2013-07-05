Active Record Session Store
===========================

A session store backed by an Active Record class. A default class is
provided, but any object duck-typing to an Active Record Session class
with text `session_id` and `data` attributes is sufficient.

Installation
------------

Include this gem into your Gemfile:

    gem 'activerecord-session_store', github: 'rails/activerecord-session_store'

Run the migration generator:

    rails generate active_record:session_migration

Then, set your session store in `config/initializers/session_store.rb`:

    Foo::Application.config.session_store :active_record_store

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

You may configure the table name, primary key, and data column.
For example, at the end of `config/application.rb`:

    ActiveRecord::SessionStore::Session.table_name = 'legacy_session_table'
    ActiveRecord::SessionStore::Session.primary_key = 'session_id'
    ActiveRecord::SessionStore::Session.data_column_name = 'legacy_session_data'

Note that setting the primary key to the `session_id` frees you from
having a separate `id` column if you don't want it. However, you must
set `session.model.id = session.session_id` by hand!  A before filter
on ApplicationController is a good place.

Since the default class is a simple Active Record, you get timestamps
for free if you add `created_at` and `updated_at` datetime columns to
the `sessions` table, making periodic session expiration a snap.

You may provide your own session class implementation, whether a
feature-packed Active Record or a bare-metal high-performance SQL
store, by setting
    
    ActionDispatch::Session::ActiveRecordStore.session_class = MySessionClass

You must implement these methods:

* `self.find_by_session_id(session_id)`
* `initialize(hash_of_session_id_and_data, options_hash = {})`
* `attr_reader :session_id`
* `attr_accessor :data`
* `save`
* `destroy`

The example SqlBypass class is a generic SQL session store. You may
use it as a basis for high-performance database-specific stores.
