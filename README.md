# russian_cities

Russian cities, federal subjects (regions) and federal districts as interlinked
[ActiveHash](https://github.com/active-hash/active_hash) models. Works in any Rails app, or plain Ruby, with no database tables.

| Model                      | Attributes                                                                                                                     | Count |
|----------------------------|--------------------------------------------------------------------------------------------------------------------------------|-------|
| `RussianCities::District`  | `id`, `name`                                                                                                                   | 8     |
| `RussianCities::Region`    | `id`, `name`, `region_type`, `district_id`                                                                                     | 85    |
| `RussianCities::City`      | `id`, `name`, `region_id`, `district_id`, `population`, `lat`, `lon`, `area_type`, `area`, `oktmo`, `municipality_type`, `municipality` | 1134  |

## Installation

```ruby
gem "russian_cities"
```

Prefer short constants (`City`, `Region`, `District`)? Opt in:

```ruby
gem "russian_cities", require: "russian_cities/global"
```

## Usage

```ruby
city = RussianCities::City.find_by(name: "Абакан")
city.region.name    # => "Хакасия"
city.district.name  # => "Сибирский"
city.population     # => 184769
city.municipality   # => "городской округ город Абакан"

bikin = RussianCities::City.find_by(name: "Бикин")
bikin.municipality_type # => "муниципальный округ"
bikin.municipality      # => "Бикинский муниципальный округ"
bikin.oktmo             # => "08509000001"

RussianCities::District.find_by(name: "Сибирский").regions
RussianCities::Region.find_by(name: "Хакасия").cities
```

### Municipal formation

`municipality` is the municipal formation (муниципальное образование) the city belongs to, taken from the current
Rosstat OKTMO. `municipality_type` is one of `"муниципальный район"`, `"муниципальный округ"`, `"городской округ"` or
`"внутригородское муниципальное образование"` (towns within federal cities, e.g. `"город Пушкин"`). `oktmo` is the
city's OKTMO code. It is the formation's 8-digit code for towns that OKTMO lists only as a formation (Пушкин,
Кронштадт). Rosstat names городские округа without their type, so `municipality` adds it: `"Губкинский"` becomes
`"Губкинский городской округ"` and `"город Абакан"` becomes `"городской округ город Абакан"`.
These fields are `nil` for Moscow, Saint Petersburg, Sevastopol, and for Балаклава, Зеленоград and Московский,
which have no formation of their own.

### Region type

`region_type` is the kind of federal subject: `"республика"`, `"край"`, `"область"`, `"автономная область"`,
`"автономный округ"` or `"город федерального значения"`.

### Short forms

`City#short_municipality`, `City#short_municipality_type` and `Region#short_name` use the ФИАС abbreviations
(Приказ Минфина № 171н): `"городской округ город Алексин"` becomes `"г.о. г. Алексин"`, `"Бикинский муниципальный
округ"` becomes `"Бикинский м.о."`, and `"Алтайский край"` becomes `"Алтайский кр."`. Republics and federal cities,
whose names carry no type, get it from `region_type`: `"респ. Хакасия"`, `"г. Москва"`.

| Full                                         | Short       |
|----------------------------------------------|-------------|
| муниципальный район                          | м.р-н       |
| муниципальный округ                          | м.о.        |
| городской округ                              | г.о.        |
| внутригородское муниципальное образование    | вн.тер.г.   |
| город-курорт                                 | г.-к.       |
| город                                        | г.          |
| район                                        | р-н         |
| область                                      | обл.        |
| край                                         | кр.         |

Only whole words are shortened, so `"город-герой"` and `"Новгород"` stay as they are.

### Administrative area

`area_type` / `area` are the administrative area (KLADR, from hflabs/city) a city belongs to, e.g. `"р-н"` /
`"Бикинский"`, `"у"` / `"Мирнинский"`, or `"г"` when the city is itself the area (Moscow Oblast городские округа).
They are `nil` for cities directly subordinate to their region (Абакан, Бикин) and for 17 cities missing from
hflabs/city. This is a different hierarchy from `municipality`, and the two often disagree. After the municipal
reforms, many районы have become муниципальные округа.

City names are not unique across regions (e.g. two "Кировск"), so look cities up by `id` or `name` + `region_id`.

### From ActiveRecord models

```ruby
class Shop < ApplicationRecord
  extend ActiveHash::Associations::ActiveRecordExtensions
  belongs_to_active_hash :city, class_name: "RussianCities::City"
end
```

## IDs are stable

IDs are assigned once and kept on every regeneration; new records are appended with the next free ID.
It is safe to store `city_id` / `region_id` / `district_id` in your database.

## Updating the data (maintainers)

The gem ships only the generated Ruby files in `lib/russian_cities/data/`. To regenerate them:

1. Bump `SOURCE_SHA` / `AREAS_SHA` in `tasks/support/data_generator.rb` to the desired upstream commits.
2. To refresh OKTMO, download the 8 volumes `OKTMO_tom*_fo.docx` from <https://rosstat.gov.ru/classification> into a
   directory and run `OKTMO_SOURCE=path/to/dir bundle exec rake data:oktmo`. This rewrites the committed
   `tasks/support/oktmo.csv` and takes a minute or two. Set `OKTMO_EDITION` in `tasks/support/data_generator.rb` to the
   edition number of the "ОКТМО_Vvedenie_red<N>.docx" introduction on the same page. rosstat.gov.ru uses a certificate
   from the Russian Trusted Root CA, which most systems do not trust by default.
3. `bundle exec rake data:generate` (or `SOURCE=path/to/russian-cities.json AREAS_SOURCE=path/to/city.csv` to use local copies).
4. `bundle exec rspec`, bump the minor version, release.

`bundle exec rake data:check` regenerates and fails if the committed data differs (useful in CI).

## Data source

Data comes from [pensnarik/russian-cities](https://github.com/pensnarik/russian-cities), which has no explicit license
(it is scraped from Wikipedia). Credit to its author.

`oktmo`, `municipality_type` and `municipality` come from the Rosstat
[OKTMO (ОК 033-2013)](https://rosstat.gov.ru/classification). It is an official state classifier, which Russian copyright
law (ГК РФ, ст. 1259) excludes from copyright.

`area_type` and `area` come from [hflabs/city](https://github.com/hflabs/city) by HFLabs, licensed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The generated `lib/russian_cities/data/cities.rb`
is therefore distributed under CC BY-SA 4.0 as well. The gem code is MIT-licensed.
