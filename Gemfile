source :rubygems

gemspec

if ENV['RAILS']
  path ENV['RAILS'] do
    gem 'actionpack'
    gem 'activerecord'
    gem 'railties'
  end
else
  git 'git://github.com/rails/rails.git' do
    gem 'actionpack'
    gem 'activerecord'
    gem 'railties'
  end
end

gem 'journey', github: 'rails/journey'
gem 'active_record_deprecated_finders', github: 'rails/active_record_deprecated_finders'
