[ '4.0', '4.1', '4.2' , '5.0', '5.1' ].each do |ver|
  appraise "rails-#{ver}" do
    gem 'actionpack',   "~> #{ver}.0"
    gem 'activerecord', "~> #{ver}.0"
    gem 'railties',     "~> #{ver}.0"
  end
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
