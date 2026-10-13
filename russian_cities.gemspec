# frozen_string_literal: true

require_relative "lib/russian_cities/version"

Gem::Specification.new do |spec|
  spec.name = "russian_cities"
  spec.version = RussianCities::VERSION
  spec.authors = ["madkox"]
  spec.email = ["madkox@madkox.net"]

  spec.summary = "Russian cities, regions and federal districts as ActiveHash models"
  spec.description = "Ships City, Region and District ActiveHash models with interlinked data " \
                     "generated from pensnarik/russian-cities. No database required."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["rubygems_mfa_required"] = "true"

  # Only the runtime code and generated data are packaged; the JSON source and generator stay in the repo.
  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "active_hash", "~> 3.3"
end
