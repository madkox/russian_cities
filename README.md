# russian_cities

Russian cities, federal subjects (regions) and federal districts as interlinked
[ActiveHash](https://github.com/active-hash/active_hash) models. Works in any Rails app, or plain Ruby, with no database tables.

| Model                      | Attributes                                                          | Count |
|----------------------------|---------------------------------------------------------------------|-------|
| `RussianCities::District`  | `id`, `name`                                                        | 8     |
| `RussianCities::Region`    | `id`, `name`, `district_id`                                         | 85    |
| `RussianCities::City`      | `id`, `name`, `region_id`, `district_id`, `population`, `lat`, `lon` | 1134  |

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

RussianCities::District.find_by(name: "Сибирский").regions
RussianCities::Region.find_by(name: "Хакасия").cities
```

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

1. Bump `SOURCE_SHA` in `tasks/support/data_generator.rb` to the desired upstream commit.
2. `bundle exec rake data:generate` (or `SOURCE=path/to/russian-cities.json` to use a local copy).
3. `bundle exec rspec`, bump the minor version, release.

`bundle exec rake data:check` regenerates and fails if the committed data differs (useful in CI).

## Data source

Data comes from [pensnarik/russian-cities](https://github.com/pensnarik/russian-cities), which has no explicit license
(it is scraped from Wikipedia). Credit to its author. The gem code is MIT-licensed.
