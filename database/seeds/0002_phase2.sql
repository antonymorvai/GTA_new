-- Seeds Phase 2: Shops, Jobs, Fahrzeugmodelle, neue Permissions.

INSERT INTO permissions (name, description) VALUES
    ('game.admin.job_set', 'Job eines Charakters setzen (wird geloggt)')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
WHERE r.name IN ('admin','developer','management') AND p.name = 'game.admin.job_set';

-- --- Shops ---
INSERT INTO shops (name, label, region, pos_x, pos_y, pos_z) VALUES
    ('supermarket_grove',  '24/7 Grove Street',   'los_santos_south', -47.5, -1757.5, 29.4),
    ('supermarket_vinewood','24/7 Vinewood',      'los_santos_north', 373.9, 325.9, 103.6),
    ('supermarket_paleto', '24/7 Paleto Bay',     'blaine_county',    -161.4, 6321.4, 31.6)
ON DUPLICATE KEY UPDATE label = VALUES(label);

-- Sortiment (Preise in Cent): identische Items, getrennte Preiszonen je Shop
INSERT IGNORE INTO shop_items (shop_id, definition_id, base_price, current_price, stock, target_stock, restock_rate, can_buy, can_sell)
SELECT s.id, d.id, prices.base, prices.base, prices.target, prices.target, prices.restock, 1, prices.can_sell
FROM shops s
JOIN item_definitions d
JOIN (
    SELECT 'water_bottle' AS def_name, 250  AS base, 100 AS target, 20 AS restock, 0 AS can_sell UNION ALL
    SELECT 'bread',                    350,        80,           15,           0 UNION ALL
    SELECT 'bandage',                  1200,       40,           8,            0
) prices ON prices.def_name = d.name;

-- --- Jobs ---
INSERT INTO jobs (name, label, is_state) VALUES
    ('unemployed', 'Arbeitslos',        0),
    ('police',     'Los Santos Police', 1),
    ('ems',        'Rettungsdienst',    1),
    ('mechanic',   'Mechaniker',        0),
    ('trucker',    'LKW-Logistik',      0)
ON DUPLICATE KEY UPDATE label = VALUES(label);

INSERT IGNORE INTO job_grades (job_id, grade, label, salary)
SELECT j.id, g.grade, g.label, g.salary FROM jobs j
JOIN (
    SELECT 'unemployed' AS job, 0 AS grade, 'Arbeitslos' AS label, 0     AS salary UNION ALL
    SELECT 'police', 0, 'Officer I',      9500  UNION ALL
    SELECT 'police', 1, 'Officer II',     11500 UNION ALL
    SELECT 'police', 2, 'Sergeant',       14500 UNION ALL
    SELECT 'police', 3, 'Lieutenant',     18000 UNION ALL
    SELECT 'police', 4, 'Chief',          23000 UNION ALL
    SELECT 'ems',    0, 'Rettungssanitäter', 9000 UNION ALL
    SELECT 'ems',    1, 'Notfallsanitäter',  11000 UNION ALL
    SELECT 'ems',    2, 'Notarzt',           16000 UNION ALL
    SELECT 'ems',    3, 'Chefarzt',          21000 UNION ALL
    SELECT 'mechanic', 0, 'Azubi',        0 UNION ALL
    SELECT 'mechanic', 1, 'Geselle',      0 UNION ALL
    SELECT 'mechanic', 2, 'Meister',      0 UNION ALL
    SELECT 'trucker',  0, 'Fahrer',       0
) g ON g.job = j.name;

-- --- Fahrzeugmodelle (Preise in Cent) ---
INSERT INTO vehicle_models (model, label, category, base_price, fuel_type, tank_liters, consumption_per_100km, dealer_stock) VALUES
    ('blista',   'Dinka Blista',      'compact',  1250000, 'petrol', 45.0, 6.5, 8),
    ('asea',     'Declasse Asea',     'sedan',    1490000, 'petrol', 55.0, 7.5, 8),
    ('faggio',   'Pegassi Faggio',    'bike',      280000, 'petrol', 8.0,  3.0, 12),
    ('sadler',   'Vapid Sadler',      'truck',    2890000, 'diesel', 90.0, 12.5, 4),
    ('dilettante','Karin Dilettante', 'compact',  1690000, 'electric', 50.0, 0.0, 5)
ON DUPLICATE KEY UPDATE label = VALUES(label);
