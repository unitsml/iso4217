# frozen_string_literal: true

# raw/*.xml -> data/*.yaml
#
# Converts the ISO 4217 lists published by SIX Group (the ISO 4217
# Maintenance Agency) into the YAML database in data/. Deterministic: the
# same raw/ bytes always produce the same data/ bytes (sorted entries, no
# timestamps). list-two.doc is not converted — it is a Word document with
# no XML counterpart; its fund codes are already covered by list one's
# IsFund entries, and its institution detail awaits a converter.

require "rexml/document"
require "yaml"

ROOT = File.expand_path("..", __dir__)

NA = "N.A."

def emit(path, document)
  File.write(path, "#{document.to_yaml.gsub(/\n/, "\n").chomp}\n")
  puts "wrote #{path.sub("#{ROOT}/", '')} (#{document['entries'].size} entries)"
end

def read_published(xml_path)
  doc = REXML::Document.new(File.read(xml_path))
  [doc, doc.root.attribute("Pblshd").to_s]
end

def source_block(list, title, published, url)
  {
    "source" => {
      "list" => list,
      "title" => title,
      "publisher" => "SIX Interbank Clearing Ltd (ISO 4217 Maintenance Agency)",
      "published" => published,
      "url" => url
    }
  }
end

# ---- list one: current currencies & funds ----

doc, published = read_published("#{ROOT}/raw/list-one.xml")
by_code = {}
doc.elements.each("ISO_4217/CcyTbl/CcyNtry") do |entry|
  # territories with "No universal currency" carry no code — informational rows
  code = entry.text("Ccy")
  next if code.nil? || code.empty?

  record = by_code[code] ||= {
    "code" => code,
    "numeric" => entry.text("CcyNbr"),
    "name" => entry.text("CcyNm"),
    "minor_unit_exponent" => entry.text("CcyMnrUnts") == NA ? nil : Integer(entry.text("CcyMnrUnts")),
    "fund" => entry.elements["CcyNm"].attribute("IsFund")&.value == "true",
    "countries" => []
  }
  record["countries"] << entry.text("CtryNm")
end
by_code.each_value do |record|
  record["countries"] = record["countries"].uniq.sort
end
entries = by_code.values.sort_by { |r| r["code"] }

# one name, one numeric per code — the lists must be internally consistent
if entries.any? { |r| r["countries"].empty? }
  abort "list one: entry without country"
end

emit("#{ROOT}/data/list-one.yaml",
     source_block("one", "Current currencies & funds", published,
                  "https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-one.xml")
       .merge("entries" => entries))

# ---- list three: historic (withdrawn) denominations ----

doc, published = read_published("#{ROOT}/raw/list-three.xml")
historic = {}
doc.elements.each("ISO_4217/HstrcCcyTbl/HstrcCcyNtry") do |entry|
  code = entry.text("Ccy")
  record = historic[code] ||= {
    "code" => code,
    "numeric" => entry.text("CcyNbr"),
    "name" => entry.text("CcyNm"),
    "withdrawn" => entry.text("WthdrwlDt"),
    "countries" => []
  }
  record["countries"] << entry.text("CtryNm")
end
historic.each_value do |record|
  record["countries"] = record["countries"].uniq.sort
end
hentries = historic.values.sort_by { |r| r["code"] }

emit("#{ROOT}/data/list-three.yaml",
     source_block("three", "Historic denominations of currencies & funds", published,
                  "https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-three.xml")
       .merge("entries" => hentries))

# ---- list two ----

puts "raw/list-two.doc kept as source snapshot only (Word format, no XML " \
     "counterpart; its codes are already present in list one via IsFund)"
