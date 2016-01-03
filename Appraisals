%w(4.0 4.1 4.2).each do |version|
  appraise version do
    gem "actionpack", "~> #{version}.0"
    gem "activerecord", "~> #{version}.0"
    gem "railties", "~> #{version}.0"
  end
end

appraise "edge" do
  git "https://github.com/rails/rails.git" do
    gem "actionpack"
    gem "activerecord"
    gem "railties"
    gem "rack", github: "rack/rack"
  end

  gem "arel", github: "rails/arel"
end
