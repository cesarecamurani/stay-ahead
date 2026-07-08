source "https://rubygems.org"

gem "bcrypt", "~> 3.1.7"
gem "bootsnap", require: false
gem "jwt"
gem "money"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "rails", "~> 8.0.0"
gem "solid_queue", "~> 1.4"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "dotenv-rails"
  gem "brakeman", require: false
  gem "factory_bot_rails"
  gem "pry"
  gem "pry-byebug"
  gem "rspec-rails"
  gem "rubocop-rails-omakase", require: false
  gem "shoulda-matchers"
  gem "webmock"
end

group :development do
  gem "web-console"
end

group :test do
  gem "simplecov", require: false
end
