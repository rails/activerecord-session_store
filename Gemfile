source :rubygems

gemspec

if ENV['RAILS']
  gem 'activerecord', path: ENV['RAILS']
  gem 'actionpack', path: ENV['RAILS']
else
  gem 'activerecord', github: 'rails/rails'
  gem 'actionpack', github: 'rails/rails'
end

gem 'journey', github: 'rails/journey'
gem 'active_record_deprecated_finders', github: 'rails/active_record_deprecated_finders'
