# frozen_string_literal: true

module RussianCities
  class City < ActiveHash::Base
    include ActiveHash::Associations

    fields :name, :region_id, :district_id, :population, :lat, :lon, :area_type, :area, :oktmo, :municipality_type, :municipality

    belongs_to :region, class_name: "RussianCities::Region"
    belongs_to :district, class_name: "RussianCities::District"
  end
end
