require "./lib/active_record/session_store/version"

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'activerecord-session_store'
  s.version     = ActiveRecord::SessionStore::VERSION
  s.summary     = 'An Action Dispatch session store backed by an Active Record class.'

  s.required_ruby_version = '>= 2.5.0'
  s.license     = 'MIT'

  s.author      = 'David Heinemeier Hansson'
  s.email       = 'david@loudthinking.com'
  s.homepage    = 'https://github.com/rails/activerecord-session_store'

  s.files        = Dir['CHANGELOG.md', 'MIT-LICENSE', 'README.md', 'lib/**/*']
  s.require_path = 'lib'

  s.extra_rdoc_files = %w( README.md )
  s.rdoc_options.concat ['--main',  'README.md']

  s.add_dependency('activerecord', '>= 6.1')
  s.add_dependency('actionpack', '>= 6.1')
  s.add_dependency('railties', '>= 6.1')
  s.add_dependency('rack', '>= 2.0.8', '< 4')
  s.add_dependency('cgi', '>= 0.3.6')

  s.add_development_dependency('sqlite3')
end
