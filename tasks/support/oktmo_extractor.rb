# frozen_string_literal: true

require "csv"
require "rexml/parsers/streamparser"
require "rexml/streamlistener"
require "zip"

module RussianCities
  # Dev-only: extracts the rows the data generator needs from the Rosstat OKTMO volumes
  # (OKTMO_tom*_fo.docx from https://rosstat.gov.ru/classification) into a small CSV:
  # municipal formations and their group headers (8-digit codes ending in 000) and cities ("г ..." settlements).
  class OktmoExtractor
    OUTPUT_PATH = File.expand_path("oktmo.csv", __dir__)
    VOLUMES_GLOB = "OKTMO_tom*_fo.docx"

    class MissingVolumes < StandardError; end

    def initialize(source_dir:)
      @source_dir = source_dir
    end

    def call
      volumes = Dir[File.join(@source_dir, VOLUMES_GLOB)].sort
      raise MissingVolumes, "Expected 8 #{VOLUMES_GLOB} files in #{@source_dir}, found #{volumes.size}" if volumes.size != 8

      rows = volumes.flat_map { |path| table_rows(path) }.filter_map { |cells| extract(cells) }.uniq
      CSV.open(OUTPUT_PATH, "w") do |csv|
        csv << %w[code name]
        rows.sort.each { |row| csv << row }
      end
      rows.size
    end

    private
      def table_rows(path)
        xml = Zip::File.open(path) { |zip| zip.read("word/document.xml") }
        listener = TableListener.new
        REXML::Parsers::StreamParser.new(xml.force_encoding(Encoding::UTF_8), listener).parse
        listener.rows
      end

      def extract(cells)
        code = cells[0].to_s.gsub(/[[:space:]]/, "")
        name = cells[2].to_s.gsub(/[[:space:]]+/, " ").strip
        return unless code.match?(/\A\d{8}\z/) && code.end_with?("000") || code.match?(/\A\d{11}\z/) && name.start_with?("г ")

        [code, name]
      end

      # Collects the text of every table cell, row by row.
      class TableListener
        include REXML::StreamListener

        attr_reader :rows

        def initialize
          @rows = []
        end

        def tag_start(name, _attrs)
          case name
          when "w:tr" then @row = []
          when "w:tc" then @cell = +""
          when "w:t" then @text = true
          end
        end

        def tag_end(name)
          case name
          when "w:tr" then @rows << @row
          when "w:tc" then @row << @cell
          when "w:t" then @text = false
          end
        end

        def text(value)
          @cell << value if @text && @cell
        end
      end
  end
end
