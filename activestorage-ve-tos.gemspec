# frozen_string_literal: true

require_relative "lib/activestorage_ve_tos/version"

Gem::Specification.new do |spec|
  spec.name = "activestorage-ve-tos"
  spec.version = ActiveStorageVeTos::VERSION
  spec.authors = ["Renny"]
  spec.summary = "ActiveStorage adapter for Volcengine TOS object storage"
  spec.description = "Wraps Volcengine TOS as an ActiveStorage service."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "activestorage-ve-tos.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ve-tos-ruby-sdk", ">= 0.1.3"
  spec.add_dependency "activestorage", ">= 6.1"

  spec.add_development_dependency "rspec", "~> 3.12"
end
