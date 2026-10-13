# frozen_string_literal: true

module RussianCities
  # Federal district (федеральный округ).
  class District < ActiveHash::Base
    include ActiveHash::Associations

    fields :name

    has_many :regions, class_name: "RussianCities::Region"
    has_many :cities, class_name: "RussianCities::City"
  end
end
