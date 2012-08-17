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
gem 'activerecord-deprecated_finders', github: 'rails/activerecord-deprecated_finders'
