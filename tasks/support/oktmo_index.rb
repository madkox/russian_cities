# frozen_string_literal: true

require "csv"

module RussianCities
  # Dev-only: resolves a city to its current OKTMO code and municipal formation (муниципальное образование)
  # using the rows OktmoExtractor wrote to oktmo.csv.
  class OktmoIndex
    # Group headers ("Муниципальные округа Белгородской области/") give the type of the formations listed under them.
    INNER_CITY = "внутригородское муниципальное образование"
    MUNICIPALITY_TYPES = {
      "Муниципальные округа" => "муниципальный округ",
      "Муниципальные районы" => "муниципальный район",
      "Городские округа" => "городской округ",
      "Внутригородские муниципальные образования" => INNER_CITY
    }.freeze
    # Formation names that may precede a city name, e.g. "город Пушкин", "городской округ Троицк".
    NAME_PREFIXES = /\A(?:город|городской округ|муниципальный округ|поселок) /i
    # City names that OKTMO spells differently.
    ALIASES = { "Ростов" => "Ростов Великий" }.freeze

    class InconsistentData < StandardError; end

    def initialize(path)
      @names = CSV.read(path, headers: true).to_h { |row| [row["code"], row["name"].delete_prefix("- ").delete_suffix("/")] }
      @cities = @names.select { |code, _| code.length == 11 }.group_by { |_, name| normalize(name.delete_prefix("г ")) }
      @formations = @names.select { |code, _| formation?(code) }.group_by { |_, name| normalize(name.sub(NAME_PREFIXES, "")) }
      @headers = @names.keys.select { |code| municipality_type_prefix(@names[code]) }.sort
    end

    # region_prefix: the region's 2-digit OKTMO code. hint: a possibly outdated OKTMO code to break ties.
    def find(name, region_prefix:, hint: nil)
      name = ALIASES.fetch(name, name)
      code = lookup(@cities, name, region_prefix, hint) || lookup(@formations, name, region_prefix, hint)
      return unless code

      formation = code[0, 5] + "000"
      type = municipality_type(formation)
      { oktmo: code, municipality: municipality_name(@names.fetch(formation), type, name), municipality_type: type }
    end

    private
      def lookup(index, name, region_prefix, hint)
        codes = index.fetch(normalize(name), []).map(&:first).select { |code| code.start_with?(region_prefix) }
        return codes.first if codes.size <= 1

        # Same-named cities within a region code, e.g. in Тюменская область and its autonomous okrugs (71 8.., 71 9..).
        best = codes.group_by { |code| common_prefix_length(code, hint.to_s) }.max_by(&:first).last
        raise InconsistentData, "Ambiguous OKTMO codes for #{name}: #{codes.inspect}" if best.size > 1

        best.first
      end

      def formation?(code)
        code.length == 8 && code.end_with?("000") && !municipality_type_prefix(@names.fetch(code))
      end

      # The nearest group header above the formation in code order, e.g. 71 850 000 "Городские округа
      # Ханты-Мансийского автономного округа" for 71 883 000 Когалым.
      def municipality_type(formation)
        header = @headers.select { |code| code < formation && code[0, 2] == formation[0, 2] }.last
        raise InconsistentData, "No group header for OKTMO #{formation} (#{@names[formation]})" unless header

        MUNICIPALITY_TYPES.fetch(municipality_type_prefix(@names.fetch(header)))
      end

      def municipality_type_prefix(name)
        MUNICIPALITY_TYPES.keys.find { |prefix| name.start_with?(prefix) }
      end

      # "Губкинский" => "Губкинский городской округ", "город Абакан" => "городской округ город Абакан",
      # "Радужный" (named after the city) => "городской округ Радужный".
      # Names that already state their type ("Бикинский муниципальный округ") and inner-city formations
      # of federal cities ("город Пушкин") are kept as is.
      def municipality_name(name, type, city_name)
        return name if type == INNER_CITY || name.downcase.include?(type)

        adjective = name.match?(/\A[[:alpha:]-]+(?:ий|ый|ой)\z/) && normalize(name) != normalize(city_name)
        adjective ? "#{name} #{type}" : "#{type} #{name}"
      end

      def common_prefix_length(left, right)
        left.each_char.zip(right.each_char).take_while { |a, b| a == b }.size
      end

      def normalize(name)
        name.tr("ёЁ", "еЕ")
      end
  end
end
