Contributing to Active Record Session Store
=====================

[![Build Status](https://travis-ci.org/rails/activerecord-session_store.svg?branch=master)](https://travis-ci.org/rails/activerecord-session_store)

Active Record Session Store is work of [many contributors](https://github.com/rails/activerecord-session_store/graphs/contributors). You're encouraged to submit [pull requests](https://github.com/rails/activerecord-session_store/pulls), [propose features and discuss issues](https://github.com/rails/activerecord-session_store/issues).

#### Fork the Project

Fork the [project on Github](https://github.com/rails/activerecord-session_store) and check out your copy.

```
git clone https://github.com/contributor/activerecord-session_store.git
cd activerecord-session_store
git remote add upstream https://github.com/rails/activerecord-session_store.git
```

#### Create a Topic Branch

Make sure your fork is up-to-date and create a topic branch for your feature or bug fix.

```
git checkout master
git pull upstream master
git checkout -b my-feature-branch
```

#### Bundle Install and Test

Ensure that you can build the project and run tests.

```
bundle install
bundle exec rake test
```

#### Write Tests

Try to write a test that reproduces the problem you're trying to fix or describes a feature that you want to build. Add to [test](test).

We definitely appreciate pull requests that highlight or reproduce a problem, even without a fix.

#### Write Code

Implement your feature or bug fix.

Make sure that `bundle exec rake test` completes without errors.

#### Write Documentation

Document any external behavior in the [README](README.md).

#### Commit Changes

Make sure git knows your name and email address:

```
git config --global user.name "Your Name"
git config --global user.email "contributor@example.com"
```

Writing good commit logs is important. A commit log should describe what changed and why.

```
git add ...
git commit
```

#### Push

```
git push origin my-feature-branch
```

#### Make a Pull Request

Go to your fork at
`https://github.com/[your github username]/activerecord-session_store` and
select your feature branch. Click the 'Pull Request' button and fill out the
form. Pull requests are usually reviewed within a few days.

#### Rebase

If you've been working on a change for a while, rebase with upstream/master.

```
git fetch upstream
git rebase upstream/master
git push origin my-feature-branch -f
```

#### Check on Your Pull Request

Go back to your pull request after a few minutes and see whether it passed muster with Travis-CI. Everything should look green, otherwise fix issues and amend your commit as described above.

#### Be Patient

It's likely that your change will not be merged and that the nitpicky maintainers will ask you to do more, or fix seemingly benign problems. Hang in there!

#### Thank You

Please do know that we really appreciate and value your time and work. We love you, really.
