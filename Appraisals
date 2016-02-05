[ '4.0', '4.1', '4.2' ].each do |ver|
  appraise "rails-#{ver}" do
    gem 'actionpack',   "~> #{ver}.0"
    gem 'activerecord', "~> #{ver}.0"
    gem 'railties',     "~> #{ver}.0"
    gem 'rack',         '~> 1.5'
  end
end

appraise 'rails-5.0' do
  gem 'actionpack',   '>= 5.0.0.alpha', '< 5.1'
  gem 'activerecord', '>= 5.0.0.alpha', '< 5.1'
  gem 'railties',     '>= 5.0.0.alpha', '< 5.1'
  gem 'rack',         '>= 2.0.0.alpha', '< 3'
end

appraise "rails-edge" do
  git 'https://github.com/rails/rails.git', :branch => 'master' do
    gem 'actionpack'
    gem 'activerecord'
    gem 'railties'
  end

  gem 'rack', :git => 'https://github.com/rack/rack.git', :branch => 'master'
  gem 'arel', :git => 'https://github.com/rails/arel.git', :branch => 'master'
end
