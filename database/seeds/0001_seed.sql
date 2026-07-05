-- Seeds: RBAC-Grundgerüst + Basis-Item-Definitionen (Testdaten).

INSERT INTO roles (name, label, priority, is_system) VALUES
    ('player',     'Spieler',        0,   1),
    ('support',    'Support',        10,  1),
    ('moderator',  'Moderator',      20,  1),
    ('admin',      'Administrator',  30,  1),
    ('developer',  'Entwickler',     40,  1),
    ('management', 'Projektleitung', 100, 1)
ON DUPLICATE KEY UPDATE label = VALUES(label);

INSERT INTO permissions (name, description) VALUES
    ('game.admin.teleport',   'In-Game-Teleport (wird geloggt)'),
    ('game.admin.item_give',  'Items erzeugen/geben (wird geloggt)'),
    ('game.admin.money_set',  'Geld setzen/anpassen (wird geloggt)'),
    ('game.admin.spectate',   'Spieler beobachten (wird geloggt)'),
    ('game.admin.kick',       'Spieler kicken'),
    ('game.admin.ban',        'Spieler bannen'),
    ('acp.player.view',       '360°-Spielerakte einsehen (Access-Log!)'),
    ('acp.logs.view',         'Log-Explorer nutzen (Access-Log!)'),
    ('acp.tuning.edit',       'Live-Tuning / Feature-Flags ändern'),
    ('acp.rbac.manage',       'Rollen und Rechte verwalten')
ON DUPLICATE KEY UPDATE description = VALUES(description);

-- Rechtematrix (kumulativ nach oben)
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
WHERE (r.name = 'support'    AND p.name IN ('acp.player.view'))
   OR (r.name = 'moderator'  AND p.name IN ('acp.player.view','acp.logs.view','game.admin.spectate','game.admin.teleport','game.admin.kick'))
   OR (r.name = 'admin'      AND p.name IN ('acp.player.view','acp.logs.view','game.admin.spectate','game.admin.teleport','game.admin.kick','game.admin.ban','game.admin.item_give','game.admin.money_set'))
   OR (r.name IN ('developer','management'));

-- Basis-Items für Tests
INSERT INTO item_definitions (name, label, category, weight_grams, max_stack, is_unique, usable) VALUES
    ('water_bottle', 'Wasserflasche',  'food',   500,  10, 0, 1),
    ('bread',        'Brot',           'food',   250,  10, 0, 1),
    ('bandage',      'Verband',        'medical',100,  10, 0, 1),
    ('phone',        'Smartphone',     'tool',   200,  1,  1, 1),
    ('weapon_pistol','Pistole',        'weapon', 900,  1,  1, 0),
    ('ammo_9mm',     '9mm-Munition',   'ammo',   12,   50, 0, 0)
ON DUPLICATE KEY UPDATE label = VALUES(label);
