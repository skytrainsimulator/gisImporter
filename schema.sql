CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE OR REPLACE FUNCTION gis.uuid_namespace()
    RETURNS uuid
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$ SELECT '3fa4a4e4-b171-4c52-8040-66c9832c16f8'::uuid $$;

CREATE OR REPLACE FUNCTION gis.osm_uuid(text) RETURNS uuid LANGUAGE SQL IMMUTABLE PARALLEL SAFE AS $$SELECT uuid_generate_v5(gis.uuid_namespace(), $1)$$;

CREATE TABLE gis.systems (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    suffix TEXT NOT NULL
);

CREATE OR REPLACE FUNCTION gis.unknown_system_uuid() RETURNS uuid LANGUAGE SQL IMMUTABLE PARALLEL SAFE AS $$ SELECT uuid_nil() $$;

INSERT INTO gis.systems (id, name, suffix) VALUES (gis.unknown_system_uuid(), 'unknown', '-UNKNOWN-SYSTEM');

CREATE TABLE gis.nodes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    point geometry(POINT, 4326) NOT NULL,
    system_id uuid NOT NULL REFERENCES gis.systems (id),
    osm_id TEXT DEFAULT NULL
);

CREATE TYPE gis.way_elevation AS ENUM ('tunnel', 'cutting', 'at_grade', 'viaduct', 'bridge');
CREATE CAST (gis.way_elevation AS text) WITH INOUT AS ASSIGNMENT ;
CREATE TYPE gis.way_service AS ENUM ('mainline', 'crossover', 'siding', 'yard', 'spur');
CREATE CAST (gis.way_service AS text) WITH INOUT AS ASSIGNMENT ;

CREATE TABLE gis.ways (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    elevation gis.way_elevation NOT NULL,
    service gis.way_service NOT NULL,
    max_speed INT NOT NULL,
    is_atc BOOLEAN NOT NULL DEFAULT TRUE,
    is_bidirectional BOOLEAN NOT NULL DEFAULT FALSE,
    osm_id TEXT DEFAULT NULL
);

CREATE TABLE gis.way_nodes (
    way uuid NOT NULL REFERENCES gis.ways (id),
    node uuid NOT NULL REFERENCES gis.nodes (id),
    ordinal INT NOT NULL,
    UNIQUE (way, ordinal)
);

CREATE TABLE gis.node_milestones (
    id uuid PRIMARY KEY REFERENCES gis.nodes (id) ON DELETE CASCADE,
    description TEXT NOT NULL
);

CREATE TABLE gis.node_buffer_stops (
    id uuid PRIMARY KEY REFERENCES gis.nodes (id) ON DELETE CASCADE
);

CREATE TABLE gis.node_crossings (
    id uuid PRIMARY KEY REFERENCES gis.nodes (id) ON DELETE CASCADE
);

CREATE TABLE gis.node_railway_crossings (
    id uuid PRIMARY KEY REFERENCES gis.nodes (id) ON DELETE CASCADE,
    way_pair_1_a uuid NOT NULL REFERENCES gis.ways (id) ON DELETE CASCADE,
    way_pair_1_b uuid NOT NULL REFERENCES gis.ways (id) ON DELETE CASCADE,
    way_pair_2_a uuid NOT NULL REFERENCES gis.ways (id) ON DELETE CASCADE,
    way_pair_2_b uuid NOT NULL REFERENCES gis.ways (id) ON DELETE CASCADE
);

CREATE TYPE gis.switch_turnout_side AS ENUM ('left', 'right', 'wye');
CREATE CAST (gis.switch_turnout_side AS text) WITH INOUT AS ASSIGNMENT;

CREATE TYPE gis.switch_type AS ENUM ('direct', 'field', 'manual');
CREATE CAST (gis.switch_type AS text) WITH INOUT AS ASSIGNMENT;

CREATE TABLE gis.node_switches (
    id uuid PRIMARY KEY REFERENCES gis.nodes (id) ON DELETE CASCADE,
    ref TEXT NOT NULL,
    type gis.switch_type NOT NULL,
    turnout_side gis.switch_turnout_side NOT NULL,
    common_way uuid NOT NULL REFERENCES gis.ways (id) ON DELETE CASCADE,
    left_way uuid NOT NULL REFERENCES gis.ways (id) ON DELETE CASCADE,
    right_way uuid NOT NULL REFERENCES gis.ways (id) ON DELETE CASCADE,
    UNIQUE (ref, type)
);

CREATE TABLE gis.node_stop_positions (
    id uuid PRIMARY KEY REFERENCES gis.nodes (id) ON DELETE CASCADE,
    ref TEXT NOT NULL UNIQUE,
    gtfs_id TEXT DEFAULT NULL
);



CREATE MATERIALIZED VIEW gis.way_nodes_cached AS
WITH all_way_nodes AS (
    SELECT way, node, ordinal FROM gis.way_nodes ORDER BY ordinal
), maxima_way_nodes AS (
    SELECT way, min(ordinal) AS min, max(ordinal) AS max FROM all_way_nodes GROUP BY way
), way_border_nodes AS (
    SELECT
        mwn.way,
        fn.node AS from_node,
        tn.node AS to_node
    FROM maxima_way_nodes mwn
    JOIN all_way_nodes fn ON fn.way = mwn.way AND fn.ordinal = mwn.min
    JOIN all_way_nodes tn ON tn.way = mwn.way AND tn.ordinal = mwn.max
), way_Lines AS (
    SELECT
        way,
        array_agg(node) AS nodes,
        st_makeline(array_agg(point ORDER BY ordinal)) AS line,
        system_id
    FROM all_way_nodes awn
    LEFT JOIN gis.nodes ON awn.node = nodes.id
    GROUP BY way, system_id
), way_lengths AS (
    SELECT way, st_lengthspheroid(line, 'SPHEROID["GRS_1980",6378137,298.257222101]') AS length FROM way_Lines
)
SELECT
    wle.way AS way,
    wle.length AS length,
    wbn.from_node AS from_node,
    wbn.to_node AS to_node,
    st_lineinterpolatepoint(line, CASE WHEN length = 0 THEN 0 ELSE greatest(0, least(1, 10 / wle.length)) END) AS from_angle_point,
    st_lineinterpolatepoint(line, 1 - CASE WHEN length = 0 THEN 0 ELSE greatest(0, least(1, 10 / wle.length)) END) AS to_angle_point,
    wl.system_id AS system_id,
    wl.nodes AS nodes,
    wl.line AS line
FROM way_lengths wle
JOIN way_lines wl ON wl.way = wle.way
JOIN way_border_nodes wbn ON wbn.way = wle.way
JOIN maxima_way_nodes mwn ON mwn.way = wle.way;

CREATE OR REPLACE FUNCTION gis.update_way_nodes_cached() RETURNS TRIGGER AS $$
BEGIN
    REFRESH MATERIALIZED VIEW gis.way_nodes_cached;
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION gis.create_way_nodes_cached_update_triggers() RETURNS VOID AS $$
    CREATE TRIGGER update_way_nodes_cached AFTER INSERT OR UPDATE OF point OR DELETE OR TRUNCATE ON gis.nodes EXECUTE FUNCTION gis.update_way_nodes_cached();
    CREATE TRIGGER update_way_nodes_cached AFTER INSERT OR UPDATE OF id OR DELETE OR TRUNCATE ON gis.ways EXECUTE FUNCTION gis.update_way_nodes_cached();
    CREATE TRIGGER update_way_nodes_cached AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON gis.way_nodes EXECUTE FUNCTION gis.update_way_nodes_cached();
    REFRESH MATERIALIZED VIEW gis.way_nodes_cached;
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION gis.drop_way_nodes_cached_update_triggers() RETURNS VOID AS $$
    DROP TRIGGER update_way_nodes_cached ON gis.nodes;
    DROP TRIGGER update_way_nodes_cached ON gis.ways;
    DROP TRIGGER update_way_nodes_cached ON gis.way_nodes;
$$ LANGUAGE sql;
SELECT gis.create_way_nodes_cached_update_triggers();

CREATE OR REPLACE VIEW gis.combined_ways AS
SELECT
    w.id,
    w.elevation,
    w.service,
    w.max_speed,
    w.is_atc,
    w.is_bidirectional,
    w.osm_id,
    wnc.from_node AS from_node,
    wnc.to_node AS to_node,
    wnc.from_angle_point AS from_angle_point,
    wnc.to_angle_point AS to_angle_point,
    wnc.system_id AS system_id,
    sys.name AS system_name,
    wnc.nodes AS nodes,
    wnc.length AS length,
    wnc.line AS line
FROM gis.ways w
JOIN gis.way_nodes_cached wnc ON w.id = wnc.way
JOIN gis.systems sys ON wnc.system_id = sys.id;

-- All nodes 1 way away from common_node
CREATE OR REPLACE VIEW gis.unordered_adj_nodes AS
SELECT
    w.to_node AS node_id,
    w.id AS way_id,
    n.point AS point,
    cn.id AS common_node,
    cn.point AS common_point,
    gis.osm_uuid(cn.id::text || w.id::text) AS adj_nodes_id
FROM gis.nodes cn
JOIN gis.combined_ways w ON w.from_node = cn.id
LEFT JOIN gis.nodes n ON n.id = w.to_node
UNION
SELECT
    w.from_node AS node_id,
    w.id AS way_id,
    n.point AS point,
    cn.id AS common_node,
    cn.point AS common_point,
    gis.osm_uuid(cn.id::text || w.id::text) AS adj_nodes_id
FROM gis.nodes cn
JOIN gis.combined_ways w ON w.to_node = cn.id
LEFT JOIN gis.nodes n ON n.id = w.from_node;

CREATE OR REPLACE FUNCTION gis.is_significantly_different_ways(w1 gis.combined_ways, w2 gis.combined_ways) RETURNS BOOLEAN AS $$
SELECT
    w1.elevation != w2.elevation OR
    w1.service != w2.service OR
    w1.max_speed != w2.max_speed OR
    w1.is_atc != w2.is_atc OR
    w1.is_bidirectional != w2.is_bidirectional OR
    (w1.to_node != w2.from_node AND w1.from_node != w2.to_node)
$$ LANGUAGE sql;

CREATE OR REPLACE VIEW gis.unordered_way_pairs AS
WITH raw AS (
    SELECT
        a1.common_node AS common_node,
        a1.node_id AS node_1_id,
        a2.node_id AS node_2_id,
        a1.way_id AS way_1_id,
        a2.way_id AS way_2_id,
        st_angle(
                CASE WHEN cw1.from_node = a1.common_node THEN cw1.from_angle_point ELSE cw1.to_angle_point END,
                a1.common_point,
                CASE WHEN cw2.from_node = a1.common_node THEN cw2.from_angle_point ELSE cw2.to_angle_point END
        ) AS angle,
        gis.is_significantly_different_ways(cw1, cw2) AS significantly_different,
        a1.point point_1,
        a2.point point_2,
        a1.common_point AS common_point,
        gis.osm_uuid(a1.way_id::text || a2.way_id::text) AS way_pair_id,
        CASE
            WHEN a1.way_id < a2.way_id THEN gis.osm_uuid(a1.way_id::text || a2.way_id::text)
            ELSE gis.osm_uuid(a2.way_id::text || a1.way_id::text)
        END as deduplicating_way_pair_id
    FROM gis.unordered_adj_nodes a1
    JOIN gis.unordered_adj_nodes a2 ON a1.common_node = a2.common_node AND a1.node_id != a2.node_id
    JOIN gis.combined_ways cw1 ON cw1.id = a1.way_id
    JOIN gis.combined_ways cw2 ON cw2.id = a2.way_id
), valid AS (
    SELECT deduplicating_way_pair_id
    FROM raw
    WHERE abs(angle - pi()) < radians(90)
    GROUP BY deduplicating_way_pair_id
    HAVING count(deduplicating_way_pair_id) = 2
)
SELECT raw.*
FROM raw
JOIN valid v ON raw.deduplicating_way_pair_id = v.deduplicating_way_pair_id;

CREATE OR REPLACE VIEW gis.significant_nodes AS
SELECT
    n.id AS id,
    bool_or(
            m.id IS NOT NULL OR
            bs.id IS NOT NULL OR
            c.id IS NOT NULL OR
            rc.id IS NOT NULL OR
            s.id IS NOT NULL OR
            sp.id IS NOT NULL OR
            wp.significantly_different
    ) AS significant
FROM gis.nodes n
    LEFT JOIN gis.node_milestones m USING (id)
    LEFT JOIN gis.node_buffer_stops bs USING (id)
    LEFT JOIN gis.node_crossings c USING (id)
    LEFT JOIN gis.node_railway_crossings rc USING (id)
    LEFT JOIN gis.node_switches s USING (id)
    LEFT JOIN gis.node_stop_positions sp USING (id)
    LEFT JOIN gis.unordered_way_pairs wp ON wp.common_node = n.id
GROUP BY n.id;

CREATE OR REPLACE VIEW gis.combined_nodes AS
SELECT
    n.id, n.point, n.osm_id,
    m.id IS NOT NULL AS is_milestone,
    m.description AS milestone_description,
    b.id IS NOT NULL AS is_buffer_stop,
    c.id IS NOT NULL AS is_crossing,
    rc.id IS NOT NULL AS is_railway_crossing,
    rc.way_pair_1_a AS railway_crossing_way_pair_1_a,
    rc.way_pair_1_b AS railway_crossing_way_pair_1_b,
    rc.way_pair_2_a AS railway_crossing_way_pair_2_a,
    rc.way_pair_2_b AS railway_crossing_way_pair_2_b,
    s.id IS NOT NULL AS is_switch,
    s.ref AS switch_ref,
    s.type AS switch_type,
    s.turnout_side AS switch_turnout_side,
    s.common_way AS switch_common_way,
    s.left_way AS switch_left_way,
    s.right_way AS switch_right_way,
    sp.id IS NOT NULL AS is_stop_position,
    sp.ref AS stop_position_ref,
    sp.gtfs_id AS stop_position_gtfs_id,
    sn.significant AS is_significant,
    n.system_id AS system_id,
    sys.name AS system_name
FROM gis.nodes n
JOIN gis.systems sys ON n.system_id = sys.id
LEFT JOIN gis.node_milestones m ON n.id = m.id
LEFT JOIN gis.node_buffer_stops b ON n.id = b.id
LEFT JOIN gis.node_crossings c ON n.id = c.id
LEFT JOIN gis.node_railway_crossings rc ON n.id = rc.id
LEFT JOIN gis.node_switches s on n.id = s.id
LEFT JOIN gis.node_stop_positions sp ON n.id = sp.id
LEFT JOIN gis.significant_nodes sn ON n.id = sn.id;

CREATE OR REPLACE FUNCTION gis.combined_nodes_upsert_row() RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.id != OLD.id) THEN RAISE EXCEPTION 'Cannot modify ID!'; END IF;

        IF (NEW.is_milestone AND NOT OLD.is_milestone) THEN
            INSERT INTO gis.node_milestones (id, description) SELECT NEW.id, NEW.milestone_description;
        ELSEIF (OLD.is_milestone AND NOT NEW.is_milestone) THEN
            DELETE FROM gis.node_milestones WHERE id = NEW.id;
        ELSEIF (NEW.is_milestone) THEN
            UPDATE gis.node_milestones SET description = NEW.milestone_description WHERE id = NEW.id;
        END IF;

        IF (NEW.is_buffer_stop AND NOT OLD.is_buffer_stop) THEN
            INSERT INTO gis.node_buffer_stops (id) SELECT NEW.id;
        ELSEIF (OLD.is_buffer_stop AND NOT NEW.is_buffer_stop) THEN
            DELETE FROM gis.node_buffer_stops WHERE id = NEW.id;
        END IF;

        IF (NEW.is_crossing AND NOT OLD.is_crossing) THEN
            INSERT INTO gis.node_crossings (id) SELECT NEW.id;
        ELSEIF (OLD.is_crossing AND NOT NEW.is_crossing) THEN
            DELETE FROM gis.node_crossings WHERE id = NEW.id;
        END IF;

        IF (NEW.is_railway_crossing AND NOT OLD.is_railway_crossing) THEN
            INSERT INTO gis.node_railway_crossings (id, way_pair_1_a, way_pair_1_b, way_pair_2_a, way_pair_2_b)
            SELECT
                NEW.id,
                NEW.railway_crossing_way_pair_1_a,
                NEW.railway_crossing_way_pair_1_b,
                NEW.railway_crossing_way_pair_2_a,
                NEW.railway_crossing_way_pair_2_b;
        ELSEIF (OLD.is_railway_crossing AND NOT NEW.is_railway_crossing) THEN
            DELETE FROM gis.node_railway_crossings WHERE id = NEW.id;
        ELSEIF (NEW.is_railway_crossing) THEN
            UPDATE gis.node_railway_crossings
            SET
                way_pair_1_a = NEW.railway_crossing_way_pair_1_a,
                way_pair_1_b = NEW.railway_crossing_way_pair_1_b,
                way_pair_2_a = NEW.railway_crossing_way_pair_2_a,
                way_pair_2_b = NEW.railway_crossing_way_pair_2_b
            WHERE id = NEW.id;
        END IF;

        IF (NEW.is_switch AND NOT OLD.is_switch) THEN
            INSERT INTO gis.node_switches (id, ref, type, turnout_side, common_way, left_way, right_way)
            SELECT NEW.id, NEW.switch_ref, NEW.switch_type, NEW.switch_turnout_side, NEW.switch_common_way, NEW.switch_left_way, NEW.switch_right_way;
        ELSEIF (OLD.is_switch AND NOT NEW.is_switch) THEN
            DELETE FROM gis.node_switches WHERE id = NEW.id;
        ELSEIF (NEW.is_switch) THEN
            UPDATE gis.node_switches
            SET
                ref = NEW.switch_ref,
                type = NEW.switch_type,
                turnout_side = NEW.switch_turnout_side,
                common_way = NEW.switch_common_way,
                left_way = NEW.switch_left_way,
                right_way = NEW.switch_right_way
            WHERE id = NEW.id;
        END IF;

        IF (NEW.is_stop_position AND NOT OLD.is_stop_position) THEN
            INSERT INTO gis.node_stop_positions (id, ref, gtfs_id)
            SELECT NEW.id, NEW.stop_position_ref, NEW.stop_position_gtfs_id;
        ELSEIF (OLD.is_stop_position AND NOT NEW.is_stop_position) THEN
            DELETE FROM gis.node_stop_positions WHERE id = NEW.id;
        ELSEIF (NEW.is_stop_position) THEN
            UPDATE gis.node_stop_positions
            SET ref = NEW.stop_position_ref, gtfs_id = NEW.stop_position_gtfs_id
            WHERE id = NEW.id;
        END IF;
        RETURN NEW;
    ELSEIF (TG_OP = 'INSERT') THEN
        INSERT INTO gis.nodes (id, point, osm_id, system_id) SELECT NEW.id, NEW.point, NEW.osm_id, NEW.system_id;
        IF (NEW.is_milestone) THEN
            INSERT INTO gis.node_milestones (id, description) SELECT NEW.id, NEW.milestone_description;
        END IF;
        IF (NEW.is_milestone) THEN
            INSERT INTO gis.node_milestones (id, description) SELECT NEW.id, NEW.milestone_description;
        END IF;
        IF (NEW.is_buffer_stop) THEN
            INSERT INTO gis.node_buffer_stops (id) SELECT NEW.id;
        END IF;
        IF (NEW.is_crossing) THEN
            INSERT INTO gis.node_crossings (id) SELECT NEW.id;
        END IF;
        IF (NEW.is_railway_crossing) THEN
            INSERT INTO gis.node_railway_crossings (id, way_pair_1_a, way_pair_1_b, way_pair_2_a, way_pair_2_b)
            SELECT
                NEW.id,
                NEW.railway_crossing_way_pair_1_a,
                NEW.railway_crossing_way_pair_1_b,
                NEW.railway_crossing_way_pair_2_a,
                NEW.railway_crossing_way_pair_2_b;
        END IF;
        IF (NEW.is_switch) THEN
            INSERT INTO gis.node_switches (id, ref, type, turnout_side, common_way, left_way, right_way)
            SELECT NEW.id, NEW.switch_ref, NEW.switch_type, NEW.switch_turnout_side, NEW.switch_common_way, NEW.switch_left_way, NEW.switch_right_way;
        END IF;
        IF (NEW.is_stop_position) THEN
            INSERT INTO gis.node_stop_positions (id, ref, gtfs_id)
            SELECT NEW.id, NEW.stop_position_ref, NEW.stop_position_ref;
        END IF;
        RETURN NEW;
    ELSEIF (TG_OP = 'DELETE') THEN
        DELETE FROM gis.nodes WHERE OLD.id = id;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER views_combined_nodes_upsert
    INSTEAD OF UPDATE OR INSERT OR DELETE ON gis.combined_nodes
    FOR EACH ROW EXECUTE PROCEDURE gis.combined_nodes_upsert_row();

CREATE OR REPLACE FUNCTION gis.combined_ways_upsert_row() RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.id != OLD.id) THEN RAISE EXCEPTION 'Cannot modify ID!'; END IF;
        UPDATE gis.ways SET
            elevation = NEW.elevation,
            service = NEW.service,
            max_speed = NEW.max_speed,
            is_atc = NEW.is_atc,
            is_bidirectional = NEW.is_bidirectional
        WHERE id = NEW.id;
        RETURN NEW;
    ELSEIF (TG_OP = 'INSERT') THEN
        INSERT INTO gis.ways (id, elevation, service, max_speed, is_atc, is_bidirectional)
        VALUES (NEW.id, NEW.elevation, NEW.service, NEW.max_speed, NEW.is_atc, NEW.is_bidirectional);
        RETURN NEW;
    ELSEIF (TG_OP = 'DELETE') THEN
        DELETE FROM gis.ways WHERE OLD.id = id;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER views_combined_ways_upsert
    INSTEAD OF UPDATE OR INSERT OR DELETE ON gis.combined_ways
    FOR EACH ROW EXECUTE PROCEDURE gis.combined_ways_upsert_row();

CREATE TYPE gis.split_result AS (split_node UUID, split_way UUID, split_ordinal INT, new_way UUID);

CREATE OR REPLACE FUNCTION gis.split_ways(splitNode uuid) RETURNS SETOF gis.split_result AS $$
DECLARE
    splitWay record;
    newId uuid;
BEGIN
    FOR splitWay IN
        WITH allWays AS (
            SELECT way, ordinal FROM gis.way_nodes wn WHERE wn.node = splitNode
        )
        SELECT DISTINCT ON (wn.way) wn.way, aw.ordinal
        FROM gis.way_nodes wn
                 JOIN allWays aw ON aw.way = wn.way
        GROUP BY wn.way, aw.ordinal
        HAVING aw.ordinal != max(wn.ordinal) AND aw.ordinal != min(wn.ordinal)
        LOOP
            newId = gis.osm_uuid(splitWay.way::text || splitWay.ordinal::text);

            INSERT INTO gis.ways (id, elevation, service, max_speed, is_atc, is_bidirectional, osm_id)
            SELECT newId, elevation, service, max_speed, is_atc, is_bidirectional, osm_id
            FROM gis.ways
            WHERE id = splitWay.way;

            UPDATE gis.way_nodes wn SET way = newId
            WHERE wn.way = splitWay.way AND wn.ordinal > splitWay.ordinal;

            INSERT INTO gis.way_nodes (way, node, ordinal) VALUES (newId, splitNode, splitWay.ordinal);
            RETURN NEXT (splitNode, splitWay.way, splitWay.ordinal, newId);
        END LOOP;
END;
$$ LANGUAGE plpgsql;
