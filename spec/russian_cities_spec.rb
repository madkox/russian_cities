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

    it "resolves nearly every city to an OKTMO municipal formation" do
      expect(city.where(municipality: nil).map(&:name))
        .to contain_exactly("Балаклава", "Зеленоград", "Москва", "Московский", "Санкт-Петербург", "Севастополь")
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

    it "types every region as a federal subject" do
      expect(region.all.map(&:region_type).tally).to eq(
        "республика" => 22, "край" => 9, "область" => 46, "автономная область" => 1, "автономный округ" => 4,
        "город федерального значения" => 3
      )
    end

    it "exposes the administrative area from hflabs/city" do
      mirny = city.find_by(name: "Мирный", region_id: region.find_by(name: "Якутия").id)

      expect(mirny).to have_attributes(area_type: "у", area: "Мирнинский")
    end

    it "resolves the current municipal formation even without an administrative area" do
      expect(city.find_by(name: "Бикин")).to have_attributes(
        area: nil, oktmo: "08509000001", municipality_type: "муниципальный округ", municipality: "Бикинский муниципальный округ"
      )
    end

    it "names городские округа by OKTMO conventions" do
      expect(abakan.municipality).to eq("городской округ город Абакан")
      expect(city.find_by(name: "Губкин").municipality).to eq("Губкинский городской округ")
      expect(city.find_by(name: "Радужный", region_id: region.find_by(name: "Ханты-Мансийский АО").id).municipality)
        .to eq("городской округ Радужный")
    end

    it "takes the municipality type from the group header inside autonomous okrugs" do
      expect(city.find_by(name: "Когалым").municipality_type).to eq("городской округ")
    end

    it "matches cities spelled without ё in the other sources" do
      expect(city.find_by(name: "Белёв")).to have_attributes(area: "Белевский", municipality: "Белевский муниципальный район")
    end

    it "falls back to inner-city formations of federal cities" do
      expect(city.find_by(name: "Пушкин")).to have_attributes(
        oktmo: "40397000", municipality_type: "внутригородское муниципальное образование", municipality: "город Пушкин"
      )
    end

    it "shortens municipality names and types" do
      expect(city.find_by(name: "Алексин")).to have_attributes(
        short_municipality_type: "г.о.", short_municipality: "г.о. г. Алексин"
      )
      expect(city.find_by(name: "Бикин").short_municipality).to eq("Бикинский м.о.")
      expect(city.find_by(name: "Абинск").short_municipality).to eq("Абинский м.р-н")
      expect(city.find_by(name: "Анапа").short_municipality).to eq("м.о. г.-к. Анапа")
      expect(city.find_by(name: "Тара").short_municipality).to eq("м.о. Тарский р-н")
      expect(city.find_by(name: "Пушкин").short_municipality_type).to eq("вн.тер.г.")
      expect(city.find_by(name: "Москва")).to have_attributes(short_municipality_type: nil, short_municipality: nil)
    end

    it "leaves words that merely contain a term intact" do
      expect(city.find_by(name: "Волгоград").short_municipality).to eq("г.о. город-герой Волгоград")
      expect(city.find_by(name: "Муром").short_municipality).to eq("г.о. округ Муром")
    end

    it "shortens region names" do
      expect(region.find_by(name: "Алтайский край").short_name).to eq("Алтайский кр.")
      expect(region.find_by(name: "Амурская область").short_name).to eq("Амурская обл.")
      expect(region.find_by(name: "Хакасия").short_name).to eq("респ. Хакасия")
      expect(region.find_by(name: "Чувашия").short_name).to eq("респ. Чувашия")
      expect(region.find_by(name: "Москва").short_name).to eq("г. Москва")
      expect(region.find_by(name: "Еврейская АО").short_name).to eq("Еврейская АО")
    end

    it "distinguishes same-named cities by region" do
      kirovsk = city.where(name: "Кировск")

      expect(kirovsk.map { |c| c.region.name }).to contain_exactly("Ленинградская область", "Мурманская область")
    end
  end
end
