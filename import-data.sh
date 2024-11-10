#!/bin/bash
set -o errexit
source util.sh

convertGeoJSON() {
  echo "Converting $1 to PGSQL..."
  time ogr2ogr -f PGDump "work/$1.sql" "work/$1.geojson" \
  -lco SCHEMA=gis -lco DROP_TABLE=OFF -lco CREATE_SCHEMA=OFF \
  -nln "osm_raw_$1" --config PG_USE_COPY YES \
  # ogr2ogr doesn't have an option to not wrap the output in a transaction
  # Normally that's sane, but in this case the script is being ran in another transaction.
  sed -i '/BEGIN;\|COMMIT;\|END;/d' "./work/$1.sql"
  echo "Done!"
}

echo "Converting OSM data to GeoJSON..."
time node index.js
echo "Done!"
convertGeoJSON nodes
convertGeoJSON ways
echo "Running import script..."
time psql -b -f import.sql
echo "Done!"
