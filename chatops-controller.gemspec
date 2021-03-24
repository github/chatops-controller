$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "chatops/controller/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "chatops-controller"
  s.version     = ChatopsController::VERSION
  s.authors     = ["Ben Lavender", "Misty De Meo", "GitHub"]
  s.homepage    = "https://github.com/github/chatops-controller"
  s.email       = ["opensource+chatops-controller@github.com"]
  s.license     = "MIT"
  s.summary     = %q{Rails helpers to create JSON-RPC chatops}
  s.description = %q{See the README for documentation}

  s.files = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "actionpack", ">= 4.0"
  s.add_dependency "activesupport", ">= 4.0"

  s.add_development_dependency "rspec-rails", "~> 3"
  s.add_development_dependency "pry", "~> 0"
end
