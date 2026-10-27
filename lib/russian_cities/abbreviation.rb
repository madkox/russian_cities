# frozen_string_literal: true

module RussianCities
  # Short forms of Russian administrative terms, following the ФИАС abbreviations (Приказ Минфина № 171н),
  # e.g. "городской округ город Алексин" => "г.о. г. Алексин".
  module Abbreviation
    # Longer phrases first, so "муниципальный округ" wins over a bare "округ".
    TERMS = {
      "внутригородское муниципальное образование" => "вн.тер.г.",
      "муниципальный район" => "м.р-н",
      "муниципальный округ" => "м.о.",
      "городской округ" => "г.о.",
      "город-курорт" => "г.-к.",
      "город" => "г.",
      "район" => "р-н",
      "область" => "обл.",
      "край" => "кр."
    }.freeze

    # Whole words only, with a case-insensitive first letter ("Муниципальный округ", "Город Кедровый").
    PATTERN = Regexp.union(
      TERMS.keys.map { |term| /(?<![\p{L}-])[#{term[0]}#{term[0].upcase}]#{Regexp.escape(term[1..])}(?![\p{L}-])/ }
    )

    def self.shorten(text)
      text&.gsub(PATTERN) { |match| TERMS.fetch(match[0].downcase + match[1..]) }
    end
  end
end
