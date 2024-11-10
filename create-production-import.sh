#!/bin/bash
set -o errexit

dumpTable() {
  echo "Dumping $1"
  pg_dump --data-only --file "production-import/$1.sql" --table "gis.$1"
}

rm -rf production-import/
mkdir production-import
dumpTable "nodes"
dumpTable "node_buffer_stops"
dumpTable "node_crossings"
dumpTable "node_milestones"
dumpTable "node_railway_crossings"
dumpTable "node_stop_positions"
dumpTable "node_switches"
dumpTable "systems"
dumpTable "ways"
dumpTable "way_nodes"
