-- Seeds: Journalisten-Job (Zeitung).

INSERT INTO jobs (name, label, is_state) VALUES
    ('journalist', 'Weazel News', 0)
ON DUPLICATE KEY UPDATE label = VALUES(label);

INSERT IGNORE INTO job_grades (job_id, grade, label, salary)
SELECT j.id, g.grade, g.label, g.salary FROM jobs j
JOIN (
    SELECT 'journalist' AS job, 0 AS grade, 'Reporter' AS label, 0 AS salary UNION ALL
    SELECT 'journalist', 1, 'Redakteur', 0 UNION ALL
    SELECT 'journalist', 2, 'Chefredakteur', 0
) g ON g.job = j.name;

-- Spuren-Kit für die Forensik (Ausgabe über Asservaten/Admin, kein Shop)
INSERT INTO item_definitions (name, label, category, weight_grams, max_stack, is_unique, usable) VALUES
    ('evidence_kit', 'Spuren-Kit', 'tool', 1500, 1, 0, 0)
ON DUPLICATE KEY UPDATE label = VALUES(label);
