#!/bin/bash
set -o errexit

rm -rf work/
mkdir work/
echo "Downloading OSM data..."
OSM_QUERY=$(cat overpass-query.txt | jq -sRr @uri)
curl -o work/raw-osm.json "https://overpass-api.de/api/interpreter?data=$OSM_QUERY"
echo "Downloaded!"
