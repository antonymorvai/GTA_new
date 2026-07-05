-- Seeds: Regierungs-Fraktion + ACP-Permission für Wahl-Verwaltung.

INSERT INTO jobs (name, label, is_state) VALUES
    ('government', 'Regierung', 1)
ON DUPLICATE KEY UPDATE label = VALUES(label);

INSERT IGNORE INTO job_grades (job_id, grade, label, salary)
SELECT j.id, g.grade, g.label, g.salary FROM jobs j
JOIN (
    SELECT 'government' AS job, 0 AS grade, 'Abgeordneter' AS label, 12000 AS salary UNION ALL
    SELECT 'government', 1, 'Minister', 18000 UNION ALL
    SELECT 'government', 2, 'Governor', 26000
) g ON g.job = j.name;

INSERT INTO permissions (name, description) VALUES
    ('acp.government.manage', 'Wahlen anlegen und verwalten')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
WHERE r.name IN ('admin') AND p.name = 'acp.government.manage';
