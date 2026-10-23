# frozen_string_literal: true

# data/*.yaml consistency validation.
#
# Enforces the ISO 4217 invariants the database must hold:
# - codes are 3 uppercase letters, unique per list
# - list one (active): numeric required, unique, minor_unit_exponent 0-4 or
#   nil (the N.A. rows), fund flag present
# - list three (historic): numeric optional — the ISO list registers
#   denominations without numerics; the withdrawn date is always present
#   (either YYYY-MM or a range string); numerics repeat legitimately across
#   a country's successive currencies, so no uniqueness there
# - a code present in both lists keeps the same numeric
# - every file names its source (list, publisher, published date, url)

require "yaml"

ROOT = File.expand_path("..", __dir__)
errors = []

load_list = ->(name) do
  path = "#{ROOT}/data/#{name}.yaml"
  abort "missing data/#{name}.yaml — run scripts/convert.rb" unless File.exist?(path)
  YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
end

list_one = load_list.call("list-one")
list_three = load_list.call("list-three")

[list_one, list_three].each do |doc|
  src = doc["source"]
  %w[list title publisher published url].each do |field|
    errors << "source.#{field} missing in a list" unless src.is_a?(Hash) && src[field] && !src[field].to_s.empty?
  end
end

check_entries = lambda do |label, entries|
  errors << "#{label}: no entries" unless entries.is_a?(Array) && !entries.empty?
  entries ||= []
  codes = Hash.new(0)
  entries.each do |entry|
    code = entry["code"]
    errors << "#{label}: bad code #{code.inspect}" unless code =~ /\A[A-Z]{3}\z/
    codes[code] += 1
    errors << "#{label}/#{code}: countries empty" unless entry["countries"].is_a?(Array) && !entry["countries"].empty?
  end
  codes.each { |code, n| errors << "#{label}: code #{code} appears #{n} times" if n > 1 }
end

check_entries.call("list-one", list_one["entries"])
check_entries.call("list-three", list_three["entries"])

numerics = Hash.new(0)
list_one["entries"].each do |entry|
  numeric = entry["numeric"]
  errors << "list-one/#{entry['code']}: bad numeric #{numeric.inspect}" unless numeric =~ /\A\d{3}\z/
  numerics[numeric] += 1
  exp = entry["minor_unit_exponent"]
  errors << "list-one/#{entry['code']}: minor_unit_exponent #{exp.inspect}" unless exp.nil? || (0..4).cover?(exp)
  errors << "list-one/#{entry['code']}: missing fund flag" unless [true, false].include?(entry["fund"])
end
numerics.each { |num, n| errors << "list-one: numeric #{num} appears #{n} times" if n > 1 }

list_three["entries"].each do |entry|
  numeric = entry["numeric"]
  errors << "list-three/#{entry['code']}: bad numeric #{numeric.inspect}" unless numeric.nil? || numeric =~ /\A\d{3}\z/
  withdrawn = entry["withdrawn"]
  # ISO publishes a YYYY-MM date for most withdrawals, but range strings
  # ("1989 to 1990", "1990-07 to 1990-09") for batch/never-circulated codes.
  # Kept verbatim; only presence is validated.
  errors << "list-three/#{entry['code']}: missing withdrawn date" unless withdrawn.is_a?(String) && !withdrawn.empty?
end

by_code_one = list_one["entries"].to_h { |e| [e["code"], e["numeric"]] }
list_three["entries"].each do |entry|
  next unless (one = by_code_one[entry["code"]])
  next if one.nil? || entry["numeric"].nil?

  errors << "#{entry['code']}: active numeric #{one} != historic numeric #{entry['numeric']}" unless one == entry["numeric"]
end

funds = list_one["entries"].count { |e| e["fund"] }
puts "list-one: #{list_one['entries'].size} codes (#{funds} funds)"
puts "list-three: #{list_three['entries'].size} historic codes"

if errors.empty?
  puts "validate: green"
else
  warn "validate: #{errors.size} error(s):"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
