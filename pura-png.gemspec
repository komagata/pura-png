# frozen_string_literal: true

require_relative "lib/pure/png/version"

Gem::Specification.new do |spec|
  spec.name = "pura-png"
  spec.version = Pura::Png::VERSION
  spec.authors = ["komagata"]
  spec.summary = "Pure Ruby PNG decoder/encoder"
  spec.description = "A pure Ruby PNG decoder and encoder with zero C extension dependencies. " \
                     "Supports all color types, bit depths, and filter types."
  spec.homepage = "https://github.com/komagata/pura-png"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "LICENSE", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["pura-png"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
