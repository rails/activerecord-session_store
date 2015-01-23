require File.expand_path('../lib/active_record/session_store/version', __FILE__)

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'activerecord-session_store'
  s.version     = ActiveRecord::SessionStore::VERSION
  s.summary     = 'An Action Dispatch session store backed by an Active Record class.'

  s.required_ruby_version = '>= 1.9.3'
  s.license     = 'MIT'

  s.author      = 'David Heinemeier Hansson'
  s.email       = 'david@loudthinking.com'
  s.homepage    = 'http://www.rubyonrails.org'

  s.files        = Dir['CHANGELOG.md', 'MIT-LICENSE', 'README.md', 'lib/**/*']
  s.require_path = 'lib'

  s.extra_rdoc_files = %w( README.md )
  s.rdoc_options.concat ['--main',  'README.md']

  s.add_dependency('activerecord', '>= 4.0.0', '< 5')
  s.add_dependency('actionpack', '>= 4.0.0', '< 5')
  s.add_dependency('railties', '>= 4.0.0', '< 5')

  s.add_development_dependency('sqlite3')
  s.add_development_dependency('appraisal')
end
