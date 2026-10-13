# frozen_string_literal: true

namespace :data do
  desc "Regenerate ActiveHash data from pensnarik/russian-cities (SOURCE=path/to/local.json to skip download)"
  task :generate do
    require_relative "support/data_generator"

    RussianCities::DataGenerator.new(source_path: ENV["SOURCE"]).call
    puts "Data written to #{RussianCities::DataGenerator::DATA_DIR}"
  end

  desc "Fail if regenerating the data changes the committed files"
  task check: :generate do
    sh "git diff --exit-code -- lib/russian_cities/data"
  end
end
