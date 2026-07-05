-- Seeds Phase 3: Basis-Gesetzbuch (in-RP per law.change änderbar) + Justiz-Job.

INSERT INTO jobs (name, label, is_state) VALUES
    ('justice', 'Justiz (DOJ)', 1)
ON DUPLICATE KEY UPDATE label = VALUES(label);

INSERT IGNORE INTO job_grades (job_id, grade, label, salary)
SELECT j.id, g.grade, g.label, g.salary FROM jobs j
JOIN (
    SELECT 'justice' AS job, 0 AS grade, 'Anwalt'         AS label, 12000 AS salary UNION ALL
    SELECT 'justice', 1, 'Staatsanwalt', 16000 UNION ALL
    SELECT 'justice', 2, 'Richter',      20000 UNION ALL
    SELECT 'justice', 3, 'Oberrichter',  25000
) g ON g.job = j.name;

INSERT INTO laws (code, title, description, fine, jail_minutes) VALUES
    ('StVO-1',  'Geschwindigkeitsüberschreitung', 'Überschreiten der zulässigen Höchstgeschwindigkeit.', 15000, 0),
    ('StVO-2',  'Fahren ohne Fahrerlaubnis', 'Führen eines Kraftfahrzeugs ohne gültige Fahrerlaubnis.', 50000, 10),
    ('StVO-3',  'Unfallflucht', 'Unerlaubtes Entfernen vom Unfallort.', 100000, 20),
    ('StGB-123','Hausfriedensbruch', 'Widerrechtliches Eindringen in fremde Räume.', 40000, 10),
    ('StGB-223','Körperverletzung', 'Körperliche Misshandlung oder Gesundheitsschädigung einer Person.', 80000, 25),
    ('StGB-242','Diebstahl', 'Wegnahme einer fremden beweglichen Sache.', 60000, 20),
    ('StGB-249','Raub', 'Wegnahme mit Gewalt oder Drohung.', 200000, 45),
    ('WaffG-1', 'Illegaler Waffenbesitz', 'Besitz einer Schusswaffe ohne Waffenschein.', 150000, 30),
    ('BtMG-1',  'Drogenbesitz', 'Besitz von Betäubungsmitteln.', 70000, 15),
    ('BtMG-2',  'Drogenhandel', 'Handel mit Betäubungsmitteln.', 250000, 60)
ON DUPLICATE KEY UPDATE title = VALUES(title);
