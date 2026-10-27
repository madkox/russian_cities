# frozen_string_literal: true

namespace :data do
  desc "Regenerate ActiveHash data from pensnarik/russian-cities, hflabs/city and tasks/support/oktmo.csv " \
       "(SOURCE=path/to/local.json, AREAS_SOURCE=path/to/city.csv to skip downloads)"
  task :generate do
    require_relative "support/data_generator"

    RussianCities::DataGenerator.new(source_path: ENV["SOURCE"], areas_path: ENV["AREAS_SOURCE"]).call
    puts "Data written to #{RussianCities::DataGenerator::DATA_DIR}"
  end

  desc "Rebuild tasks/support/oktmo.csv from the Rosstat OKTMO volumes (OKTMO_SOURCE=dir/with/OKTMO_tom*_fo.docx)"
  task :oktmo do
    require_relative "support/oktmo_extractor"

    count = RussianCities::OktmoExtractor.new(source_dir: ENV.fetch("OKTMO_SOURCE")).call
    puts "#{count} rows written to #{RussianCities::OktmoExtractor::OUTPUT_PATH}"
  end

  desc "Fail if regenerating the data changes the committed files"
  task check: :generate do
    sh "git diff --exit-code -- lib/russian_cities/data"
  end
end
