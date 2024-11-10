\set ON_ERROR_STOP on
BEGIN;

TRUNCATE
    gis.nodes,
    gis.node_buffer_stops,
    gis.node_crossings,
    gis.node_milestones,
    gis.node_railway_crossings,
    gis.node_stop_positions,
    gis.node_switches,
    gis.ways,
    gis.systems,
    gis.way_nodes;

SELECT gis.drop_way_nodes_cached_update_triggers();
\i production-import/systems.sql
\i production-import/nodes.sql
\i production-import/ways.sql
\i production-import/way_nodes.sql
\i production-import/node_buffer_stops.sql
\i production-import/node_crossings.sql
\i production-import/node_milestones.sql
\i production-import/node_railway_crossings.sql
\i production-import/node_stop_positions.sql
\i production-import/node_switches.sql
SELECT gis.create_way_nodes_cached_update_triggers();

COMMIT;
