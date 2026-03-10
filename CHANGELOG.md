## Unreleased

## 2.2.1

* Deprecate support for `sessions.sessid` column. In 3.0, only
  `sessions.session_id` will be supported.
* Add `secure_session_only` configuration to disable accepting insecure
  sessions.
* Drop Rails 7.0 support.

## 2.2.0

* Drop dependency on `multi_json`.
