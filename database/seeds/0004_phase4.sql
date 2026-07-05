-- Seeds Phase 4: Ressourcen-Pools, Territorien, Gangs, Deal-Spots,
-- Drogen-/Rohstoff-Items, Immobilien.

-- Items der Ketten
INSERT INTO item_definitions (name, label, category, weight_grams, max_stack, is_unique, usable) VALUES
    ('fish',        'Fisch',              'resource', 800,  20, 0, 0),
    ('iron_ore',    'Eisenerz',           'resource', 2000, 20, 0, 0),
    ('wood_log',    'Holzstamm',          'resource', 5000, 10, 0, 0),
    ('weed_raw',    'Cannabis (Rohware)', 'drug',     100,  20, 0, 0),
    ('weed_packed', 'Cannabis (Päckchen)','drug',     50,   20, 0, 0)
ON DUPLICATE KEY UPDATE label = VALUES(label);

-- Ressourcen-Pools (endlich, regenerierend)
INSERT INTO resource_pools (pool_type, label, pos_x, pos_y, pos_z, radius, capacity, current, regen_per_tick, item_name, skill) VALUES
    ('fishing', 'Del Perro Pier',        -1850.1, -1248.5, 8.6,   40, 120, 120, 8, 'fish', 'fishing'),
    ('fishing', 'Alamo See Nord',         -1601.5, 4494.2, 19.8,  50, 80,  80,  6, 'fish', 'fishing'),
    ('mining',  'Davis Quartz Steinbruch', 2954.1, 2783.5, 41.0,  60, 150, 150, 10, 'iron_ore', 'mining'),
    ('logging', 'Paleto Forest',           -560.9, 5252.7, 70.5,  80, 100, 100, 7, 'wood_log', 'logging'),
    ('farming', 'Grapeseed Felder (illegal)', 2222.9, 5152.6, 57.8, 60, 60, 60, 4, 'weed_raw', 'farming')
ON DUPLICATE KEY UPDATE label = VALUES(label);

-- Territorien & Beispiel-Gangs
INSERT INTO territories (name, label, center_x, center_y, radius) VALUES
    ('grove',   'Grove Street',   -150.0, -1610.0, 300),
    ('vespucci','Vespucci Beach', -1200.0, -1400.0, 350),
    ('mirror',  'Mirror Park',      1100.0, -600.0, 300)
ON DUPLICATE KEY UPDATE label = VALUES(label);

INSERT INTO gangs (name, label) VALUES
    ('families', 'The Families'),
    ('ballas',   'Ballas')
ON DUPLICATE KEY UPDATE label = VALUES(label);

-- Deal-Spots (Director rotiert 'active')
INSERT INTO deal_spots (label, pos_x, pos_y, pos_z, active) VALUES
    ('Grove Street Hinterhof',   -136.1, -1610.5, 35.0, 1),
    ('Vespucci Skatepark',       -1372.4, -1288.3, 4.4, 0),
    ('Mirror Park Parkplatz',     1160.9, -580.4, 64.2, 0),
    ('La Mesa Unterführung',      780.6, -1360.1, 26.5, 0),
    ('Sandy Shores Motel',        1568.2, 3591.5, 38.8, 0)
ON DUPLICATE KEY UPDATE label = VALUES(label);

-- Immobilien
INSERT INTO properties (label, prop_type, region, entrance_x, entrance_y, entrance_z, base_price, current_price) VALUES
    ('Alta Street Apartment 12',  'apartment', 'los_santos_north', -269.9, -955.2, 31.2, 8500000,  8500000),
    ('Grove Street Haus 4',       'house',     'los_santos_south', -14.2, -1441.5, 31.1, 6200000,  6200000),
    ('Vespucci Apartment 3B',     'apartment', 'vespucci',        -1147.7, -1520.6, 10.6, 7800000, 7800000),
    ('La Mesa Lagerhalle',        'warehouse', 'la_mesa',          796.0, -1024.5, 26.2, 15000000, 15000000)
ON DUPLICATE KEY UPDATE label = VALUES(label);
