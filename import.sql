-- This import script contains generic import logic. There should be no hardcoded IDs, coordinates, etc. in this file.

\set ON_ERROR_STOP on
BEGIN;

DROP SCHEMA IF EXISTS gis CASCADE;
CREATE SCHEMA gis;

\i schema.sql
\i work/nodes.sql
\i work/ways.sql
CREATE TABLE gis.osm_raw_way_nodes (
    raw_way TEXT NOT NULL,
    raw_node TEXT NOT NULL,
    ordinal INT NOT NULL,
    UNIQUE(raw_way, ordinal)
);
\i work/way_nodes.sql

-- osm2geojson includes nodes in the ways dataset
DELETE FROM gis.osm_raw_ways WHERE id NOT LIKE 'way%';

\i dataset-specific/pre-osm-parse.sql

-- Load all nodes from osm_raw_nodes into nodes
INSERT INTO gis.nodes (id, point, osm_id, system_id)
SELECT gis.osm_uuid(r.id), r.wkb_geometry, r.id, gis.unknown_system_uuid()
FROM gis.osm_raw_nodes r;

-- Load all ways from osm_raw_ways into ways. There's a bit more data here so some defaults are set.
INSERT INTO gis.ways (id, elevation, service, max_speed, is_bidirectional, osm_id)
SELECT
    gis.osm_uuid(r.id),
    (CASE
       WHEN r.bridge = 'viaduct' THEN 'viaduct'
       WHEN r.bridge IS NOT NULL AND r."bridge:name" IS NOT NULL THEN 'bridge'
       WHEN r.bridge IS NOT NULL AND r."bridge:name" IS NULL THEN 'viaduct'
       WHEN r.cutting IS NOT NULL THEN 'cutting'
       WHEN r.tunnel = 'yes' THEN 'tunnel'
       WHEN r.tunnel = 'building-passage' THEN 'tunnel'
       ELSE 'at_grade'
    END)::gis.way_elevation,
    CASE WHEN r.service IS NOT NULL THEN r.service::gis.way_service ELSE 'mainline' END,
    CASE
       WHEN r.maxspeed IS NOT NULL THEN r.maxspeed::int
       WHEN r.service IS NOT NULL THEN
           CASE r.service
               WHEN 'mainline' THEN 90
               WHEN 'crossover' THEN 25
               WHEN 'siding' THEN 25
               WHEN 'yard' THEN 15
               WHEN 'spur' THEN 15
               ELSE 15
           END
       ELSE 90
    END,
    coalesce(r.service = 'siding' OR r.service = 'crossover' OR r.service = 'spur', FALSE),
    r.id
FROM gis.osm_raw_ways r;

SELECT gis.drop_way_nodes_cached_update_triggers();

INSERT INTO gis.way_nodes (way, node, ordinal)
SELECT gis.osm_uuid(raw_way), gis.osm_uuid(raw_node), ordinal
FROM gis.osm_raw_way_nodes;

WITH significantIds AS (
    SELECT gis.osm_uuid(id) AS id FROM gis.osm_raw_nodes WHERE railway IS NOT NULL
)
SELECT count(split_ways.*) AS numSplitWays FROM significantIds
JOIN gis.split_ways(id) ON split_ways.split_node = id;

SELECT gis.create_way_nodes_cached_update_triggers();

\i dataset-specific/post-osm-parse.sql

-- Load buffer stops, crossings from osm_raw_nodes using the railway=buffer_stop and railway=level_crossing / crossing tags
INSERT INTO gis.node_buffer_stops (id) SELECT gis.osm_uuid(id) FROM gis.osm_raw_nodes WHERE railway = 'buffer_stop';
INSERT INTO gis.node_crossings (id) SELECT gis.osm_uuid(id) FROM gis.osm_raw_nodes WHERE railway = 'crossing' OR railway = 'level_crossing';

WITH crossings AS (
    SELECT gis.osm_uuid(n.id) as id FROM gis.osm_raw_nodes n WHERE n.railway = 'railway_crossing'
), way_pairs AS (
    SELECT DISTINCT ON (deduplicating_way_pair_id)
        c.id AS crossing_id,
        way_1_id, way_2_id,
        gis.osm_uuid(way_1_id::text || way_2_id::text) AS dedup_id
    FROM crossings c
    JOIN gis.unordered_way_pairs wp ON c.id = wp.common_node
    WHERE abs(angle - pi()) < radians(10)
    ORDER BY deduplicating_way_pair_id
)
INSERT INTO gis.node_railway_crossings (id, way_pair_1_a, way_pair_1_b, way_pair_2_a, way_pair_2_b)
SELECT DISTINCT ON (wp1.crossing_id)
    wp1.crossing_id, wp1.way_1_id, wp1.way_2_id, wp2.way_1_id, wp2.way_2_id
FROM way_pairs wp1
JOIN way_pairs wp2 ON wp1.crossing_id = wp2.crossing_id AND wp1.dedup_id != wp2.dedup_id;

WITH switches AS (
    SELECT
        n.id AS id,
        coalesce(rn.ref, 'NULL-' || n.id) || sys.suffix AS ref,
        (CASE WHEN rn."railway:switch:local_operated" = 'yes' OR rn."railway:switch:electric" = 'no' THEN 'manual' ELSE 'direct' END)::gis.switch_type AS type
    FROM gis.osm_raw_nodes rn
    JOIN gis.nodes n ON n.id = gis.osm_uuid(rn.id)
    JOIN gis.systems sys ON n.system_id = sys.id
    WHERE rn.railway = 'switch'
), duplicate_refs AS (
    SELECT ref, type FROM switches GROUP BY ref, type HAVING COUNT(*) > 1
), way_pairs AS (
    SELECT
        id, ref, type,
        way_1_id, way_2_id,
        angle,
        wp.deduplicating_way_pair_id AS dedup
    FROM switches
    JOIN gis.unordered_way_pairs wp ON switches.id = wp.common_node
    ORDER BY wp.deduplicating_way_pair_id, wp.way_1_id
), common_ways AS (
    SELECT
        id, way_1_id AS common_way
    FROM way_pairs
    GROUP BY id, way_1_id
    HAVING count(way_1_id) > 1
)
INSERT INTO gis.node_switches (id, ref, type, turnout_side, common_way, left_way, right_way)
SELECT DISTINCT ON (wp1.id)
    wp1.id,
    wp1.ref || CASE WHEN dr.ref IS NOT NULL THEN '-CONFLICT-' || wp1.id ELSE '' END,
    wp1.type,
    CASE WHEN (wp1.angle + wp2.angle) / 2 < pi() THEN 'left' ELSE 'right' END::gis.switch_turnout_side AS turnout_side,
    cw.common_way AS common_way,
    CASE WHEN wp1.angle < wp2.angle THEN wp1.way_2_id ELSE wp2.way_2_id END AS left_way,
    CASE WHEN wp1.angle < wp2.angle THEN wp2.way_2_id ELSE wp1.way_2_id END AS right_way
FROM common_ways cw
JOIN way_pairs wp1 ON cw.id = wp1.id AND cw.common_way = wp1.way_1_id
JOIN way_pairs wp2 ON cw.id = wp2.id AND cw.common_way = wp2.way_1_id AND wp1.way_2_id != wp2.way_2_id
LEFT JOIN duplicate_refs dr ON dr.ref = wp1.ref AND dr.type = wp1.type
ORDER BY wp1.id;

-- Load the stop positions from osm_raw_nodes using the railway=stop tag
-- as well as nodes with railway=milestone and the railway:positon tag set (this seems to be how non-station stop points
-- are marked in OSM)
WITH stop_positions AS (
    SELECT
        n.id AS id, rn."railway:ref" || sys.suffix AS ref
    FROM gis.osm_raw_nodes rn
    JOIN gis.nodes n ON gis.osm_uuid(rn.id) = n.id
    JOIN gis.systems sys ON n.system_id = sys.id
    WHERE rn.railway = 'stop'
    UNION
    SELECT
        n.id AS id, rn."railway:position" || sys.suffix AS ref
    FROM gis.osm_raw_nodes rn
    JOIN gis.nodes n ON gis.osm_uuid(rn.id) = n.id
    JOIN gis.systems sys ON n.system_id = sys.id
    WHERE rn.railway = 'milestone' AND rn."railway:position" IS NOT NULL AND rn.ref != 'EXI' AND rn.ref != 'EXO'
), duplicate_refs AS (
    SELECT ref FROM stop_positions GROUP BY ref HAVING COUNT(*) > 1
)
INSERT INTO gis.node_stop_positions (id, ref)
SELECT
    stop_positions.id,
    CASE WHEN stop_positions.ref = duplicate_refs.ref THEN (stop_positions.ref || '-CONFLICT-'|| stop_positions.id) WHEN stop_positions.ref IS NULL THEN 'NULL-' || stop_positions.id ELSE stop_positions.ref END
FROM stop_positions
LEFT JOIN duplicate_refs USING (ref);

--
INSERT INTO gis.node_milestones (id, description)
SELECT
    gis.osm_uuid(id),
    coalesce(name || ' ' || note, note, name)
FROM gis.osm_raw_nodes r WHERE r.railway = 'milestone' AND r."railway:position" IS NULL;

\i dataset-specific/post-import.sql

COMMIT;
