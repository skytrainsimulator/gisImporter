-- ## pre-osm-parse.sql ## --
-- Executed after gis.osm_raw_nodes, gis.osm_raw_ways, and gis.osm_raw_way_nodes are loaded, but before any of the
-- schema-defined tables are populated. Use if there's data that's easier to fix in the osm tables before the import
-- logic runs than after.

-- Mainline track marked as crossover?
UPDATE gis.osm_raw_ways SET service = 'mainline'
WHERE id = 'way/494354325';

-- Some CL OMC switches "marked" as manual simply with a M prefix
UPDATE gis.osm_raw_nodes SET "railway:switch:electric" = 'no', ref = trim(LEADING 'M' FROM ref)
WHERE railway = 'switch' AND ref LIKE 'M%';

-- Switches not marked as manual
WITH manual_switches AS ( VALUES
    ('node/1030282426'),
    ('node/1030282519'),
    ('node/1030282578'),
    ('node/1030282623'),
    ('node/1030282707'),
    ('node/1030282889'),
    ('node/1030282961'),
    ('node/4454496695'),
    ('node/4454496699')
)
UPDATE gis.osm_raw_nodes SET "railway:switch:electric" = 'no'
FROM manual_switches
WHERE id = manual_switches.column1;

-- No refs for the following switches
WITH switches AS ( VALUES
    ('node/4454496695', '?1?'),
    ('node/4454496699', '?2?'),
    ('node/4454496702', '?3?'),
    ('node/8573215808', '?4?'),
    ('node/8140799026', '311?'),
    ('node/8140799027', '312?')
)
UPDATE gis.osm_raw_nodes SET ref = switches.column2
FROM switches
WHERE id = switches.column1;

-- These 2 stop positions are marked as buffer_stops for some reason?
WITH borked AS ( VALUES ('node/5328382011'), ('node/430022542'))
UPDATE gis.osm_raw_nodes SET railway = 'stop'
FROM borked
WHERE id = borked.column1;
