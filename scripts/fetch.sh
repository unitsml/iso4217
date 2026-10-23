#!/bin/sh
# Re-download the ISO 4217 lists from SIX Group (the ISO 4217 Maintenance
# Agency) into raw/. Fail hard on any non-200 so stale snapshots are never
# mistaken for fresh ones. After fetching, run scripts/convert.rb and review
# the data/ diff before opening a PR.
#
# Note: the "iso-currrency" misspelling is part of SIX's own published URL.
set -eu

cd "$(dirname "$0")/../raw"

BASE="https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency"

for file in lists/list-one.xml lists/list-three.xml lists/list-two.doc; do
  name=${file#lists/}
  echo "fetching $file"
  curl -fsSL -o "$name.tmp" "$BASE/$file"
  mv "$name.tmp" "$name"
done

echo "fetched: $(ls)"
echo "now run: ruby scripts/convert.rb && ruby scripts/validate.rb"
