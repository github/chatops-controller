$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "chatops_controller/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "chatops_controller"
  s.version     = ChatopsController::VERSION
  s.authors     = ["Ben Lavender"]
  s.email       = ["bhuga@github.com"]
  s.summary       = %q{Rails helpers to create JSON-RPC chatops}

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.6"

  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "pry"
end
