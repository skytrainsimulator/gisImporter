-- ## post-import.sql ## --
-- Executed after all standard import logic. All tables should be populated from osm_raw_<>, this file is for any fixes
-- or additions needed

-- TODO move to pre-osm-parse
WITH _stop_positions AS ( VALUES
    ('7021def6-315b-5da8-84b6-85e1983eb1a7', 'BUI'),
    ('8344f1f0-a44a-57e0-9437-f934a06ce5b3', 'BUO'),
    ('03185347-a2fe-5968-a78c-d82d64a28089', 'GVI'),
    ('17f9700e-3bc1-5539-958d-2e0b4f304fa6', 'GVO'),
    ('a9eef647-e8cb-53e1-9901-0d0593794ac6', 'MNI'),
    ('2c2796a4-04a8-5da8-aeca-c43889c73a57', 'MNO'),
    ('2b4c056f-ce78-5f33-8652-b502ffe1aba3', 'BWI'),
    ('bb412b6e-de56-5bcb-ab1d-ead20b5325d2', 'BWO'),
    ('90a94fa1-361c-5178-8039-3c070f3e1ca6', 'NAI'),
    ('8ee591b9-76df-5904-9ab9-834b937d3e05', 'NAO'),
    ('f8c92c51-c7e4-5e44-89bf-ad2e8582ddf2', 'TNI'),
    ('4a53e510-fc43-5c4e-b6eb-f73371423eb0', 'TNO'),
    ('b42466c9-846a-54ac-b8b2-0f8fa812d2cc', 'JYI'),
    ('d042afa6-7170-5399-997a-ba1184be05db', 'JYO'),
    ('fcb577b8-2a3d-52fa-a841-87aaa289b489', 'PTI'),
    ('f033655a-bf5e-5d7f-82e4-4aa56b215570', 'PTO'),
    ('1d9792bd-2db1-5e7c-821b-4749a92f96b7', 'MTI'),
    ('bf98a8a4-c6cd-5f77-b9fd-0fafff62c0c1', 'MTO'),
    ('9cc6d3be-6721-561a-9c1b-10093c0b8129', 'NWI'),
    ('6a59de7a-e234-5467-91e6-3935057630b0', 'NWO'),
    ('14f617c2-b35b-5c72-9354-78e6f4f894d7', 'COI'),
    ('d13fb16e-7924-5f0a-8b91-78dff9300270', 'COO'),
    ('8c2e69f5-5518-519c-a631-6b1e522af584', 'GWI'),
    ('59a6b371-7eb1-5927-ab76-d526409f565d', 'GWO'),
    ('4a32ea67-4741-5d4f-85c0-2a9837d98d55', 'SCI'),
    ('6c3bca59-20c2-5bb5-b4bb-26d8f695f982', 'SCO'),

    ('653ba890-2e8a-52e4-af20-1a9a5487e724', 'BDI'),
    ('ec8ba275-6bd9-5f1a-a220-8acbf30e5157', 'BDO'),
    ('43961617-301a-565b-b343-fa1bff6340f2', 'SAI'),
    ('7ab2c526-0bdb-54d2-ada7-d2f292f299a1', 'SAO'),

    ('c274bc56-1ccb-5d5c-aac8-dfad15425d7c', 'CMI'),
    ('0b6ddaf8-62aa-542f-a563-86db3cc6e6c8', 'CMO'),
    ('1a80ec32-22ac-5c56-95d7-67a001946d90', 'RUI'),
    ('872999b6-cde6-5dd7-997e-44b162279b64', 'RUO'),
    ('8abad0cd-9ec1-5c3a-930b-128f6c5a3f18', 'BRI'),
    ('cacce329-17bf-5b8b-be8d-e365078c1f88', 'BRO'),
    ('5c8c3950-e77d-5275-bc95-d2fe0cbd2b27', 'SPI'),
    ('5555a253-fcdd-5077-9e13-717876c37e1d', 'SPO'),
    ('72d4759c-23f7-5ad8-8292-9d2c9532210b', 'LCI'),
    ('9cfc7d76-6148-5edc-97ac-143c61616b99', 'LCO'),
    ('13aad658-039b-583c-9645-9b701b701340', 'PWI'),
    ('53fc07c6-f7bb-5821-8f0a-179d44e193b9', 'PWO'),
    ('7b52529e-b549-5c80-9407-792dfadfe041', 'LHI'),
    ('af5c4920-58a0-5bfa-b375-836568b26735', 'LHO'),
    ('7b10d159-8e73-51a6-83b5-8f16f57ba38b', 'LHS'),
    ('37e4bba4-c73e-54f1-8f85-e68bf90806ae', 'BQI'),
    ('d632ba86-c2d2-50af-9563-fac4e2a12bba', 'BQO'),
    ('769d189f-4960-552a-a980-6d542b5ec466', 'MCI'),
    ('23e3ab33-83c6-57b5-8f35-e9d9d89881a6', 'MCO'),
    ('4e9a8b70-00dd-5184-a525-6943323b7a43', 'ICI'),
    ('bfa777bb-7ada-5d6c-93ec-968904fa5407', 'ICO'),
    ('292ad9ef-fab6-5d6c-9d95-afe9b488b90b', 'LNI'),
    ('cbe4be9c-121f-51d1-89a7-c65d94eebccf', 'LNO'),

    ('dd3bd587-befc-5979-84f5-52d433abf882', 'BCIC'),
    ('b2f8ec89-d832-52a5-a6fe-8ee0e8a3ee50', 'BCOC'),
    ('fd960488-d76c-5160-8d0e-ea6412004c29', 'KEIC'),
    ('38587ebe-42f4-54b7-b1cc-f6e0b5612400', 'KEOC'),
    ('d61780de-7b15-553f-8bae-1d6e43d09d5d', 'OKIC'),
    ('12f74c9b-1f1a-5fe3-bf08-4d6445b3c0da', 'OKOC'),
    ('f23c0c62-3347-58d8-978c-3b87896fee6d', 'BPIC'),
    ('90e18866-6fba-55f8-b72d-04684f1c14ae', 'BPOC'),

    ('573b61fc-70bb-52ca-b52c-6d6ed58614ce', 'TMIC'),
    ('a8ed7dec-2073-5436-bbd4-50855db0aa51', 'TMOC'),
    ('2de0d977-e4ce-5f36-b325-ee72730c85b6', 'SIIC'),
    ('ea1a9ac9-34a9-5825-a774-e427fcfbe2fa', 'SIOC'),

    ('c5d8d907-7746-5c08-9ecd-980743a20aa9', 'ABIC'),
    ('81471a23-d0d5-5fda-be00-fd77887d0cdd', 'ABOC'),
    ('7933e8f6-34e5-5df4-ae9b-0b414fb32964', 'LDIC'),
    ('260b2b96-964e-57f0-a323-94f0ef57ebc8', 'LDOC')
), stop_positons AS (
    SELECT column1::uuid AS id, column2 AS ref FROM _stop_positions
)
UPDATE gis.node_stop_positions osp
SET ref = sp.ref
FROM stop_positons sp
WHERE osp.id = sp.id;

WITH _gtfsPlatformMap AS ( VALUES
    ('8039', 'WFO'),
    ('8078', 'WFI'),
    ('8040', 'BUO'),
    ('8077', 'BUI'),
    ('8041', 'GVO'),
    ('8076', 'GVI'),
    ('8042', 'STO'),
    ('8075', 'STI'),
    ('8043', 'MNO'),
    ('8074', 'MNI'),
    ('8044', 'BWO'),
    ('8073', 'BWI'),
    ('8045', 'NAO'),
    ('8072', 'NAI'),
    ('8046', 'TNO'),
    ('8071', 'TNI'),
    ('8047', 'JYO'),
    ('8070', 'JYI'),
    ('8048', 'PTO'),
    ('8069', 'PTI'),
    ('8049', 'MTO'),
    ('8068', 'MTI'),
    ('8050', 'ROO'),
    ('8067', 'ROI'),
    ('8051', 'EDO'),
    ('8066', 'EDI'),
    ('8052', 'TSO'),
    ('8065', 'TSI'),
    ('8053', 'NWO'),
    ('8064', 'NWI'),
    ('8054', 'COO'),
    ('8063', 'COI'),

    ('8062', 'SRI'),
    ('8055', 'SRO'),
    ('8061', 'GWI'),
    ('8056', 'GWO'),
    ('8060', 'SCI'),
    ('8057', 'SCO'),
    ('8059', 'KGI'),
    ('8058', 'KGO'),

    ('8577', 'BDO'),
    ('8578', 'BDI'),
    ('8579', 'SAO'),
    ('8580', 'SAI'),

    ('10374', 'VCO'),
    ('10375', 'VCI'),
    ('8763', 'CMO'),
    ('8754', 'CMI'),
    ('8762', 'REO'),
    ('8753', 'REI'),
    ('8761', 'RUO'),
    ('8752', 'RUI'),
    ('8760', 'GMO'),
    ('8751', 'GMI'),
    ('8759', 'BRO'),
    ('8750', 'BRI'),
    ('8758', 'HOO'),
    ('8749', 'HOI'),
    ('8757', 'SPO'),
    ('8748', 'SPI'),
    ('9511', 'LCO'),
    ('9510', 'LCI'),
    ('8756', 'PWO'),
    ('8747', 'PWI'),
    ('8755', 'LHO'),
    ('8746', 'LHI'),
    ('12227', 'LHS'),

    ('12229', 'BQO'),
    ('12228', 'BQI'),
    ('12231', 'MCO'),
    ('12230', 'MCI'),
    ('12233', 'ICO'),
    ('12232', 'ICI'),
    ('12235', 'CCO'),
    ('12234', 'CCI'),
    ('12237', 'LNO'),
    ('12236', 'LNI'),
    ('12239', 'LAO'),
    ('12238', 'LAI'),

    ('11302', 'WFOC'),
    ('11303', 'WFIC'),
    ('11272', 'VCOC'),
    ('11273', 'VCIC'),
    ('11274', 'YTOC'),
    ('11275', 'YTIC'),
    ('11276', 'OVOC'),
    ('11277', 'OVIC'),
    ('11278', 'BCOC'),
    ('11279', 'BCIC'),
    ('11280', 'KEOC'),
    ('11281', 'KEIC'),
    ('11282', 'OKOC'),
    ('11283', 'OKIC'),
    ('11284', 'LGOC'),
    ('11285', 'LGIC'),
    ('11286', 'MDOC'),
    ('11287', 'MDIC'),
    ('8759', 'BPOC'),
    ('11289', 'BPIC'),

    ('11296', 'TMOC'),
    ('11297', 'TMIC'),
    ('11298', 'SIOC'),
    ('11299', 'SIIC'),
    ('11301', 'APC'),

    ('11290', 'ABOC'),
    ('11291', 'ABIC'),
    ('11292', 'LDOC'),
    ('11293', 'LDIC'),
    ('11295', 'RBC')
), gtfsPlatformMap AS (
    SELECT column2 AS stop_pos, column1 AS stop_id FROM _gtfsPlatformMap
)
UPDATE gis.node_stop_positions sp
SET gtfs_id = pm.stop_id
FROM gtfsPlatformMap pm
WHERE pm.stop_pos = sp.ref;

WITH wye_switches AS ( VALUES
    ('25aa2831-0936-5c31-8da4-aa32db20d925'),
    ('37cf3529-f91d-5a51-82dd-5915806788d8'),
    ('2698f703-0ee7-5d43-b9fd-5e96d04c4c9a'),
    ('aed95c2d-74fe-53f2-b869-10748c9f3744'),
    ('7af74ec2-92c2-5487-a97c-4db67bb3c56b'),
    ('f789b866-fe54-569b-aac6-05fb847d2a14'),
    ('2bdfd3c4-6ad9-50fc-8efe-f7fd8fa5270c'),
    ('7a36f81a-a43c-5be9-be90-7b462f33fb62'),
    ('9de5027d-945b-5f2f-94f9-d94a469dab76')
)
UPDATE gis.node_switches SET turnout_side = 'wye'
FROM wye_switches
WHERE wye_switches.column1::uuid = node_switches.id;

-- This...mess finds a mainline-only path from A to B, and ensures the found path's ways are all directed from A to B
SELECT gis.drop_way_nodes_cached_update_triggers();
WITH _mainlines AS (
    VALUES
        -- CANADA LINE
        ('1dbb7b87-e209-5dbb-8d64-31b93939841b', 'dde611bb-bbfb-5b65-a7c9-d50866f08878'), --      WFO  - 366 ( AP)
        ('dde611bb-bbfb-5b65-a7c9-d50866f08878', '5cad841b-f452-5acf-9bd4-a3e949dbc0bc'), -- 366 ( AP) -      WFI
        ('015976c6-1459-5339-8352-98c60d84aa99', '811c12d5-9dd4-5e0c-b6a3-f3b0853bf2bd'), -- 326 (BPO) - 342 ( RB)
        ('811c12d5-9dd4-5e0c-b6a3-f3b0853bf2bd', '20a8aefb-8a31-5ad3-9f0f-cd78423076ba'), -- 342 ( RB) - 325 (BPI)
        -- LIM SYSTEM
        ('4508848d-c004-5ba4-a2bd-fe6083944160', 'af85934c-c674-595e-96ba-b3b41ca8f23a'), --   2 (WFO) -  59 (KGO)
        ('fd3c4fec-9171-5c1e-a7c9-8f455017eb9e', 'e66f6e66-7452-5bc6-94f1-af87fcc8e9d3'), --  58 (KGI) -   1 (WFI)
        ('b6f92f66-16d6-5e53-9a69-c0fd9f028056', 'ffc5ab0f-b57c-5099-b8a8-039f7e44e5fe'), --      VCO  -  44 (COI)
        ('4500aa32-23ce-57fd-8010-b6f0b73c7709', '93a67a18-6750-559d-a321-f2fe17a1eab8'), --  45 (COO) -      VCI
        ('3fc83348-a3ec-568a-8267-58fc567cbb0f', '4da293fe-2fde-5ba9-b116-0d2ae73e2bcf'), -- 160 (LHI) -      LTO
        ('25e56adc-0768-5d49-a64e-5e2c0eedf0f2', '5180e60c-25e0-5e39-9d27-f53359d8072d')  --      LTI  - 155 (LHS)
), mainlines AS (
    SELECT column1::uuid AS from_node, column2::uuid AS to_node FROM _mainlines
), recursive AS (
    WITH RECURSIVE rec AS (
        SELECT
            an.common_node AS from_node,
            an.node_id AS to_node,
            ARRAY[an.way_id] AS ways,
            ARRAY[an.common_node, an.node_id] as nodes,
            st_distancesphere(an.common_point, an.point) AS total_distance
        FROM gis.unordered_adj_nodes an, gis.ways w, mainlines
        WHERE
            an.common_node = mainlines.from_node AND
            an.way_id = w.id AND
            w.service = 'mainline'
        UNION
        SELECT
            r.from_node,
            an.node_id,
            r.ways || an.way_id,
            r.nodes || an.node_id,
            r.total_distance + st_distancesphere(an.common_point, an.point)
        FROM rec r, mainlines, gis.unordered_adj_nodes an
        JOIN gis.ways w ON an.way_id = w.id
        LEFT JOIN gis.node_switches s ON s.id = an.common_node
        WHERE
            r.to_node = an.common_node AND
            NOT (an.way_id = ANY (r.ways)) AND
            w.service = 'mainline' AND
            r.from_node = mainlines.from_node AND
            an.common_node != mainlines.to_node AND
            (
                s.id IS NULL OR
                r.ways[array_upper(r.ways, 1)] = s.common_way OR
                an.way_id = s.common_way
            )
    ) SELECT rec.* FROM rec, mainlines WHERE rec.from_node = mainlines.from_node AND rec.to_node = mainlines.to_node
), unnested AS (
    SELECT unnest(ways) AS way, from_node, to_node, nodes, ways FROM recursive
), needs_flip AS (
    SELECT u.way, w.to_node = u.nodes[array_position(u.ways, u.way)] AND w.from_node = u.nodes[array_position(u.ways, u.way) + 1] AS needs_flip
    FROM unnested u
    JOIN gis.combined_ways w ON u.way = w.id
)
UPDATE gis.way_nodes wn SET ordinal = -wn.ordinal
FROM needs_flip nf
WHERE nf.way = wn.way AND nf.needs_flip;
SELECT gis.create_way_nodes_cached_update_triggers();

WITH yard_ways AS ( VALUES
    -- OMC1
    ('3ead78fe-924e-542b-b137-953760fbf5fd'),
    ('d362d8d7-70ee-521b-b40a-fdf2338289d6'),
    ('ca240f62-2e64-5039-b93e-b21713dacffa'),
    ('2e54f56d-f19e-5956-a4a5-757f20220d4b'),
    ('fdd06679-1cba-5ee9-ac3c-870bf25e0080'),
    ('4377682c-f361-5527-bf5d-c7c1153f4781'),
    ('d9aa6463-21b2-5020-b63e-8f59392a847f'),
    ('2bdc1931-0302-5f65-aca6-131431d0d633'),
    ('dfea7199-9e8c-52bc-a266-2fc3692b5ad1'),
    ('bd9ff988-9ba3-57fe-bcb8-b21331d0c129'),
    ('5886ff80-d5c2-5039-b766-7f7d2120ea5f'),
    ('94432d92-ca95-508c-8c7c-87903636fdba'),
    ('7e9a7b1b-1902-5fcb-af5b-2f81725c9ce5'),
    ('01c69a90-23e3-5f4d-8e18-51e09b017d87'),
    ('5d9f9971-1455-5659-9d8d-1d7c280dae4c'),
    ('ea743cce-1643-543b-86f3-abbc7fb1d5a1'),
    ('14877793-7d50-50aa-8d75-3ce4762d6454'),
    ('6fac08dd-e86b-529f-b975-7befca317544'),
    ('d8fe637b-3d60-550a-9666-17130a35dbe4'),
    ('c24b72bf-e044-5491-b687-718306ed01c5'),
    ('5912142c-d1d1-52be-b26f-fa9f7570ed90'),
    ('739dc74a-4691-5845-ab4f-26f22bbc41af'),
    ('cbd2e8da-56e5-5c16-a2f8-ada29843a3dc'),
    ('0215ded5-0c2f-53bd-9624-65831fdb2568'),
    ('64c503c4-57d9-59c2-820f-a290c958a254'),
    ('65b14e60-1428-5087-a702-739eac8b7946'),
    ('056f3913-5422-5e96-9c3d-d2b7fc934719'),
    ('1a494dad-d901-585b-bef7-5db6fbd933f1'),
    ('3f04fd28-83b0-5bc7-9974-1c2beef4ed12'),
    ('9c2c6bc6-19a7-5a7c-8ca4-142e35d1aaa8'),
    ('4581e69d-784c-5b65-a61e-4dafad92317d'),
    ('b4e559bb-7ba9-514e-b557-04c5cffdf68e'),
    ('03654bc9-7cb0-5d1d-b379-e164ad6c7756'),
    ('3242ed84-88dc-51df-b682-4704db87709d'),
    ('c5708abf-24df-5204-80fe-0d678bae84ac'),
    ('a6b9e3c7-4887-5788-970f-ba73cc3ebc38'),
    ('f24ff3a4-5f4a-5487-97c9-65c538278b7b'),
    ('c975cad0-3fec-55cc-8c56-87ac3d94f6c6'),
    ('3759e270-0b44-5d89-862d-23f5c35d6bc1'),
    ('d14bd2b3-9cab-560f-9152-beb01abdc322'),
    ('ade4691e-459d-57fb-af02-d7fa817d2134'),
    ('bcee42cf-0e44-5493-b0cd-2bf8159e5cd3'),
    ('b2774238-3f4e-5733-998f-1a714c947a71'),
    ('1a3e82fb-8c9c-50e0-814f-f62702fcc7f3'),
    ('43af7213-3e25-5c13-95ab-e96b120a3707'),
    ('20e5ffb8-5df0-5511-89c8-8b31f4367b17'),
    ('7322fbe7-4364-55b8-a80b-62cf0d07a1d6'),
    ('283fe945-68b7-5ad6-b592-be61b74675af'),
    ('4800fc0f-e3dd-5f09-85cd-af7a7a722e54'),
    ('eff7422b-0a32-5d07-9d16-d12da07131dc'),
    ('82066cec-f197-5895-904e-45dd246bb06c'),
    ('d1a9a2aa-abbf-5f8e-8299-262bbcf97c71'),
    ('7e1b9d05-f7a9-518c-8599-8d07b41f428d'),
    ('ba86a234-f703-5b3c-baab-4c315fd94d2d'),

    -- OMC3
    ('354d857a-c8f2-5d24-a72d-1d2a088332e0'),

    -- CL OMC
    ('1b18db32-88d4-5594-8db0-7d9be7e7e2f9'),
    ('08f0e4a9-4fb4-529f-98eb-56650c01e914'),
    ('46118820-6338-5c2b-93cb-a8c6c450fc88'),
    ('d513b490-51a4-5618-be02-800de852d724'),
    ('508ef01f-4b19-5331-a714-941399a1f62b'),
    ('f04f2feb-b797-5adf-8ffd-997a645ce923'),
    ('7749c4a5-6e7b-5bcf-9194-ffb6c9ff5818'),
    ('80c29ef2-174b-52f6-a98b-9d5336171c34'),
    ('5896fc28-4b9e-5f88-b664-33cd0bcdd793'),
    ('41574613-e0ae-505c-b127-e2c26e35e072'),
    ('be6dfc23-a944-57df-ab0f-5e7481fcfcb1'),
    ('77193692-0820-5bec-a9c4-ab7737f0affe'),
    ('693a5b52-410c-5e17-8c4e-32ab072c88f4'),
    ('5aea22e6-8ed1-5318-bf60-81129f873595'),
    ('ffe85c10-93b8-5238-9ac8-423f5905d9e0'),
    ('7b857eac-46af-5ce3-992a-39ff545759f5'),
    ('a76113c1-fb48-5259-a706-93f42350de15'),
    ('6eaeaca6-e7a1-5db0-909c-f74f93370a81')
)
UPDATE gis.ways SET is_bidirectional = TRUE, is_atc = FALSE
FROM yard_ways
WHERE ways.id = yard_ways.column1::uuid;
