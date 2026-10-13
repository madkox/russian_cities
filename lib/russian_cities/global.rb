# frozen_string_literal: true

# Opt-in short constants: `require "russian_cities/global"` (or `gem "russian_cities", require: "russian_cities/global"`).
require_relative "../russian_cities"

City = RussianCities::City
Region = RussianCities::Region
District = RussianCities::District
