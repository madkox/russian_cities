# frozen_string_literal: true

module RussianCities
  # Federal subject (субъект РФ).
  class Region < ActiveHash::Base
    include ActiveHash::Associations

    fields :name, :district_id

    belongs_to :district, class_name: "RussianCities::District"
    has_many :cities, class_name: "RussianCities::City"
  end
end
