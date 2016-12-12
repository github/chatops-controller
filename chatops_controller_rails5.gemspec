$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "chatops_controller/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "chatops_controller"
  s.version     = ChatopsController::VERSION
  s.authors     = ["Ben Lavender"]
  s.homepage    = "https://github.com/github/chatops_controller"
  s.email       = ["bhuga@github.com"]
  s.license     = "unknown - maybe we'll open source this?"
  s.summary     = %q{Rails helpers to create JSON-RPC chatops}
  s.description = %q{See the README for documentation"}

  s.files = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", "~> 5.0"

  s.add_development_dependency "rspec-rails", "~> 3"
  s.add_development_dependency "rspec_json_dumper", "~> 0.1"
  s.add_development_dependency "pry", "~> 0"
end
