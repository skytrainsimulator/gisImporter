-- ## post-osm-parse.sql ## --
-- Executed after gis.nodes, gis.ways, and gis.way_nodes is populated, but before any of the other node component
-- tables are populated.

INSERT INTO gis.systems (id, name, suffix)
VALUES
    ('fcbe482c-3ed5-4fc3-b361-a256de04416f', 'LIM', ''),
    ('cfce3fe3-f983-49b0-927f-425518224bdd', 'Canada', 'C');

-- TODO improve the performance of this. Currently this is the single slowest step of importing.
WITH _systems AS (
    VALUES
        -- LIM, WTB Buffer stop
        ('fcbe482c-3ed5-4fc3-b361-a256de04416f', '57618b7e-c693-596d-bfa0-21438ac00f61'),
        -- Canada, WFO buffer stop
        ('cfce3fe3-f983-49b0-927f-425518224bdd', '1dbb7b87-e209-5dbb-8d64-31b93939841b')
), systems AS (
    SELECT column1::uuid AS system_id, column2::uuid as node_id FROM _systems
), way_systems AS (
    WITH RECURSIVE rec AS (
        SELECT
            sys.system_id AS system,
            wn.way AS way
        FROM systems sys
        JOIN gis.way_nodes wn ON sys.node_id = wn.node
        UNION
        SELECT
            rec.system,
            adj.way_id
        FROM rec
        JOIN gis.combined_ways w ON w.id = rec.way
        JOIN gis.unordered_adj_nodes adj ON (w.to_node = adj.common_node OR w.from_node = adj.common_node) AND NOT adj.way_id IN (rec.way)
    ) SELECT * FROM rec
), node_systems AS (
    SELECT DISTINCT
        ws.system,
        wn.node
    FROM way_systems ws
    JOIN gis.way_nodes wn ON ws.way = wn.way
)
UPDATE gis.nodes n SET system_id = ns.system
FROM node_systems ns
WHERE ns.node = n.id;
