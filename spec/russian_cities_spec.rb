# frozen_string_literal: true

RSpec.describe RussianCities do
  let(:district) { RussianCities::District }
  let(:region) { RussianCities::Region }
  let(:city) { RussianCities::City }

  describe "data volume" do
    it { expect(district.count).to eq(8) }
    it { expect(region.count).to eq(85) }
    it { expect(city.count).to eq(1134) }
  end

  describe "referential integrity" do
    it "links every region to an existing district" do
      expect(region.all.map(&:district)).to all(be_a(district))
    end

    it "links every city to an existing region and district" do
      expect(city.all.map(&:region)).to all(be_a(region))
      expect(city.all.map(&:district)).to all(be_a(district))
    end

    it "keeps city district consistent with its region's district" do
      mismatched = city.all.reject { |c| c.district_id == c.region.district_id }

      expect(mismatched).to be_empty
    end

    it "has unique ids per model" do
      [district, region, city].each do |model|
        expect(model.all.map(&:id)).to eq(model.all.map(&:id).uniq)
      end
    end
  end

  describe "lookups" do
    subject(:abakan) { city.find_by(name: "Абакан") }

    it "exposes all attributes" do
      expect(abakan).to have_attributes(population: 184_769, lat: 53.71667, lon: 91.41667)
    end

    it "resolves belongs_to associations" do
      expect(abakan.region.name).to eq("Хакасия")
      expect(abakan.district.name).to eq("Сибирский")
    end

    it "resolves has_many associations" do
      siberia = district.find_by(name: "Сибирский")

      expect(siberia.regions).to include(abakan.region)
      expect(siberia.cities).to include(abakan)
      expect(abakan.region.cities).to include(abakan)
    end

    it "distinguishes same-named cities by region" do
      kirovsk = city.where(name: "Кировск")

      expect(kirovsk.map { |c| c.region.name }).to contain_exactly("Ленинградская область", "Мурманская область")
    end
  end
end
