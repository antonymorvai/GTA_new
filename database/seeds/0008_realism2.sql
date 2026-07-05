-- Seeds: Werkzeug, Werkbank-Pflicht für anspruchsvolle Rezepte, Drogen-Konsum.

INSERT INTO item_definitions (name, label, category, weight_grams, max_stack, is_unique, usable) VALUES
    ('toolbox', 'Werkzeugkasten', 'tool', 4000, 1, 0, 0)
ON DUPLICATE KEY UPDATE label = VALUES(label);

-- Cannabis ist konsumierbar (Wirkung + Sucht via hrp_drugs)
UPDATE item_definitions SET usable = 1 WHERE name = 'weed_packed';

-- Dietrich & Reparatur-Kit brauchen Werkzeugkasten + Werkbank
UPDATE crafting_recipes SET tool_item = 'toolbox', tool_wear = 12, requires_workbench = 1
WHERE name IN ('lockpick', 'repair_kit');

-- Werkzeugkasten im Shop-Sortiment
INSERT IGNORE INTO shop_items (shop_id, definition_id, base_price, current_price, stock, target_stock, restock_rate, can_buy, can_sell)
SELECT s.id, d.id, 12000, 12000, 15, 15, 3, 1, 0
FROM shops s JOIN item_definitions d ON d.name = 'toolbox';
