# frozen_string_literal: true

module RussianCities
  # Federal subject (субъект РФ).
  class Region < ActiveHash::Base
    include ActiveHash::Associations

    fields :name, :region_type, :district_id

    belongs_to :district, class_name: "RussianCities::District"
    has_many :cities, class_name: "RussianCities::City"

    # "Хакасия" => "респ. Хакасия", "Москва" => "г. Москва", "Алтайский край" => "Алтайский кр."
    def short_name
      case region_type
      when "республика" then "респ. #{name}"
      when "город федерального значения" then "г. #{name}"
      else Abbreviation.shorten(name)
      end
    end
  end
end
