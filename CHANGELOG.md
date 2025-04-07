# Change Log

All notable changes to this project will be documented in this file.

## Unreleased

* Default to the request's `cookies_same_site_protection` setting, brining
    `ActiveRecordStore` in line with the default behavior of `CookieStore`.
    [@sharman [#222](https://github.com/rails/activerecord-session_store/pull/222)]
* Drop Rails 7.0 support.
    [@sharman [#221](https://github.com/rails/activerecord-session_store/pull/221)]

## 2.2.0

* Drop dependency on `multi_json`.
