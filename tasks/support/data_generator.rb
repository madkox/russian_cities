# frozen_string_literal: true

require "csv"
require "json"
require "net/http"
require "active_hash"

require_relative "../../lib/russian_cities/district"
require_relative "../../lib/russian_cities/region"
require_relative "../../lib/russian_cities/city"
require_relative "oktmo_index"

module RussianCities
  # Dev-only: turns pensnarik/russian-cities JSON into ActiveHash data files,
  # enriching cities with area (район) from hflabs/city and municipal formation from the Rosstat OKTMO
  # (pre-extracted to oktmo.csv by `rake data:oktmo`).
  # IDs already present in the committed data files are kept; new records get max_id + 1.
  class DataGenerator
    SOURCE_REPO = "pensnarik/russian-cities"
    SOURCE_SHA = "e4ba0919bcdfb00debe96798a0810d9091a7bfc2"
    SOURCE_URL = "https://raw.githubusercontent.com/#{SOURCE_REPO}/#{SOURCE_SHA}/russian-cities.json"
    AREAS_REPO = "hflabs/city"
    AREAS_SHA = "ae661bffe572880472249097c9b29c42b09650ea"
    AREAS_URL = "https://raw.githubusercontent.com/#{AREAS_REPO}/#{AREAS_SHA}/city.csv"
    OKTMO_EDITION = "950"
    OKTMO_PATH = File.expand_path("oktmo.csv", __dir__)
    DATA_DIR = File.expand_path("../../lib/russian_cities/data", __dir__)

    # hflabs region names that don't follow the "<name> <type>" pattern of pensnarik subjects.
    AREAS_REGION_NAMES = {
      "Еврейская" => "Еврейская АО",
      "Кабардино-Балкарская" => "Кабардино-Балкария",
      "Карачаево-Черкесская" => "Карачаево-Черкесия",
      "Кемеровская область - Кузбасс" => "Кемеровская область",
      "Саха /Якутия/" => "Якутия",
      "Северная Осетия - Алания" => "Северная Осетия",
      "Удмуртская" => "Удмуртия",
      "Ханты-Мансийский Автономный округ - Югра" => "Ханты-Мансийский АО",
      "Чеченская" => "Чечня",
      "Чувашская Республика" => "Чувашия"
    }.freeze
    AREAS_REGION_SUFFIXES = { "обл" => "область", "край" => "край", "АО" => "АО" }.freeze

    class InconsistentData < StandardError; end

    def initialize(source_path: nil, areas_path: nil)
      @source_path = source_path
      @areas_path = areas_path
    end

    def call
      load_existing_data
      rows = parse_source
      areas = parse_areas
      oktmo = OktmoIndex.new(OKTMO_PATH)

      districts = build_districts(rows)
      regions = build_regions(rows, districts)
      cities = build_cities(rows, areas, oktmo, regions, districts)

      write("districts", District, districts.values)
      write("regions", Region, regions.values)
      write("cities", City, cities.values)
    end

    private
      def load_existing_data
        %w[districts regions cities].each do |name|
          path = File.join(DATA_DIR, "#{name}.rb")
          load(path) if File.exist?(path)
        end
      end

      def parse_source
        json = @source_path ? File.read(@source_path) : Net::HTTP.get(URI(SOURCE_URL))
        JSON.parse(json)
      end

      # Indexes hflabs rows by [city name, pensnarik subject name].
      # Rows without a city are the city itself as an area (e.g. "г Воскресенск") or a federal city.
      def parse_areas
        csv = @areas_path ? File.read(@areas_path) : Net::HTTP.get(URI(AREAS_URL)).force_encoding(Encoding::UTF_8)
        rows = CSV.parse(csv, headers: true)
        index = rows.group_by do |row|
          name = row["settlement"] || row["city"] || row["area"] || row["region"]
          area_key(name, areas_region_name(row))
        end

        duplicates = index.select { |_, matches| matches.size > 1 }.keys
        raise InconsistentData, "Duplicate hflabs cities: #{duplicates.inspect}" if duplicates.any?

        index.transform_values(&:first)
      end

      def areas_region_name(row)
        name = row.fetch("region")
        AREAS_REGION_NAMES[name] || [name, AREAS_REGION_SUFFIXES[row.fetch("region_type")]].compact.join(" ")
      end

      # Every hflabs OKTMO code of a region shares its 2-digit region code.
      def region_prefixes(areas)
        areas.group_by { |(_, region), _| region }.to_h do |region, matches|
          prefixes = matches.map { |_, row| row.fetch("oktmo")[0, 2] }.uniq
          raise InconsistentData, "Region #{region} has several OKTMO codes: #{prefixes.inspect}" if prefixes.size > 1

          [region, prefixes.first]
        end
      end

      # The sources disagree on ё (e.g. "Киселёвск" vs "Киселевск").
      def area_key(name, region)
        [name.tr("ё", "е"), region]
      end

      def build_districts(rows)
        ids = IdAllocator.new(District.all.to_h { |district| [district.name, district.id] })

        rows.map { |row| row.fetch("district") }.uniq.sort.to_h do |name|
          [name, { id: ids.fetch(name), name: name }]
        end
      end

      def build_regions(rows, districts)
        ids = IdAllocator.new(Region.all.to_h { |region| [region.name, region.id] })
        pairs = rows.map { |row| [row.fetch("subject"), row.fetch("district")] }.uniq

        pairs.group_by(&:first).each do |region, region_pairs|
          raise InconsistentData, "Region #{region} belongs to several districts" if region_pairs.size > 1
        end

        pairs.sort.to_h do |name, district|
          [name, { id: ids.fetch(name), name: name, district_id: districts.fetch(district)[:id] }]
        end
      end

      def build_cities(rows, areas, oktmo, regions, districts)
        existing = City.all.to_h { |city| [[city.name, city.region&.name], city.id] }
        ids = IdAllocator.new(existing)
        prefixes = region_prefixes(areas)

        cities = rows.sort_by { |row| [row.fetch("name"), row.fetch("subject")] }.map do |row|
          key = [row.fetch("name"), row.fetch("subject")]
          area = areas[area_key(*key)]
          municipality = oktmo.find(key.first, region_prefix: prefixes.fetch(key.last), hint: area&.[]("oktmo"))
          [key, city_attributes(row, ids.fetch(key), area, municipality, regions, districts)]
        end

        duplicates = cities.map(&:first).tally.select { |_, count| count > 1 }.keys
        raise InconsistentData, "Duplicate cities: #{duplicates.inspect}" if duplicates.any?

        cities.to_h
      end

      def city_attributes(row, id, area, municipality, regions, districts)
        coords = row.fetch("coords")
        {
          id: id,
          name: row.fetch("name"),
          region_id: regions.fetch(row.fetch("subject"))[:id],
          district_id: districts.fetch(row.fetch("district"))[:id],
          population: row["population"],
          lat: coords["lat"]&.to_f,
          lon: coords["lon"]&.to_f,
          area_type: area&.[]("area_type"),
          area: area&.[]("area"),
          oktmo: municipality&.[](:oktmo),
          municipality_type: municipality&.[](:municipality_type),
          municipality: municipality&.[](:municipality)
        }
      end

      def write(name, klass, records)
        lines = records.sort_by { |record| record[:id] }.map { |record| "  #{format_record(record)}," }
        File.write(File.join(DATA_DIR, "#{name}.rb"), <<~RUBY)
          # frozen_string_literal: true

          # AUTO-GENERATED by `rake data:generate` from #{SOURCE_REPO}@#{SOURCE_SHA},
          # #{AREAS_REPO}@#{AREAS_SHA} and OKTMO (ОК 033-2013) edition #{OKTMO_EDITION}. Do not edit by hand.
          #{klass.name}.data = [
          #{lines.join("\n")}
          ]
        RUBY
      end

      def format_record(record)
        "{#{record.map { |key, value| "#{key}: #{value.inspect}" }.join(", ")}}"
      end

      # Hands out the previously committed ID for a key, or the next free one.
      class IdAllocator
        def initialize(existing)
          @existing = existing
          @next_id = (existing.values.max || 0) + 1
        end

        def fetch(key)
          @existing[key] ||= begin
            id = @next_id
            @next_id += 1
            id
          end
        end
      end
  end
end
