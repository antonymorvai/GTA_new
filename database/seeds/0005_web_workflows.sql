-- Seeds: Permissions für Ticket-/Bewerbungs-/Sanktions-Workflows.

INSERT INTO permissions (name, description) VALUES
    ('acp.whitelist.review', 'Whitelist-Bewerbungen prüfen und entscheiden'),
    ('acp.tickets.manage',   'Tickets/Reports bearbeiten (Access-Log!)'),
    ('acp.sanctions.manage', 'Verwarnungen/Bans aussprechen (Begründung + Beweis Pflicht)')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
WHERE (r.name = 'support'   AND p.name IN ('acp.whitelist.review','acp.tickets.manage'))
   OR (r.name = 'moderator' AND p.name IN ('acp.whitelist.review','acp.tickets.manage','acp.sanctions.manage'))
   OR (r.name = 'admin'     AND p.name IN ('acp.whitelist.review','acp.tickets.manage','acp.sanctions.manage'));
