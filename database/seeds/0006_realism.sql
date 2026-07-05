-- Seeds: Crafting-Materialien, Rezepte, Waffen-Nutzbarkeit, Shop-Sortiment.

INSERT INTO item_definitions (name, label, category, weight_grams, max_stack, is_unique, usable) VALUES
    ('cloth',        'Stoff',           'material', 200,  20, 0, 0),
    ('metal_parts',  'Metallteile',     'material', 1500, 20, 0, 0),
    ('lockpick',     'Dietrich',        'tool',     100,  5,  0, 0),
    ('repair_kit',   'Reparatur-Kit',   'tool',     3000, 3,  0, 0)
ON DUPLICATE KEY UPDATE label = VALUES(label);

-- Waffen & Munition sind "benutzbar" (Ausrüsten/Laden statt Konsum)
UPDATE item_definitions SET usable = 1 WHERE name IN ('weapon_pistol', 'ammo_9mm');

INSERT INTO crafting_recipes (name, label, output_item, output_qty, skill, min_level, xp_reward, inputs) VALUES
    ('bandage',    'Verband herstellen',      'bandage',    2, 'crafting', 0, 12, '[{"item":"cloth","qty":2}]'),
    ('lockpick',   'Dietrich feilen',         'lockpick',   1, 'crafting', 2, 20, '[{"item":"metal_parts","qty":2}]'),
    ('repair_kit', 'Reparatur-Kit zusammenbauen', 'repair_kit', 1, 'crafting', 3, 30, '[{"item":"metal_parts","qty":3},{"item":"cloth","qty":1}]')
ON DUPLICATE KEY UPDATE label = VALUES(label);

-- Materialien in den Shops verfügbar machen
INSERT IGNORE INTO shop_items (shop_id, definition_id, base_price, current_price, stock, target_stock, restock_rate, can_buy, can_sell)
SELECT s.id, d.id, prices.base, prices.base, prices.target, prices.target, prices.restock, 1, 0
FROM shops s
JOIN item_definitions d
JOIN (
    SELECT 'cloth' AS def_name, 800 AS base, 60 AS target, 10 AS restock UNION ALL
    SELECT 'metal_parts',       2500,        40,           6
) prices ON prices.def_name = d.name;
