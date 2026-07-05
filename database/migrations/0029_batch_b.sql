-- 0029: Fahrzeug-Tuning-Stufe + Funkgerät-Item.

ALTER TABLE vehicles
    ADD COLUMN tune_stage TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER last_service_km;

INSERT INTO item_definitions (name, label, category, weight_grams, max_stack, is_unique, usable) VALUES
    ('radio', 'Funkgerät', 'tool', 500, 1, 0, 0)
ON DUPLICATE KEY UPDATE label = VALUES(label);

INSERT IGNORE INTO shop_items (shop_id, definition_id, base_price, current_price, stock, target_stock, restock_rate, can_buy, can_sell)
SELECT s.id, d.id, 25000, 25000, 10, 10, 2, 1, 0
FROM shops s JOIN item_definitions d ON d.name = 'radio';
