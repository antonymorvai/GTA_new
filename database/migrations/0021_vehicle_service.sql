-- 0021: Fahrzeug-Wartung — Kilometerstand beim letzten Service.
-- Verschleiß steigt mit gefahrenen km; jenseits des Wartungsintervalls
-- verschleißt der Motor doppelt so schnell (Tuning: vehicles.*).

ALTER TABLE vehicles
    ADD COLUMN last_service_km DECIMAL(10,1) NOT NULL DEFAULT 0 AFTER mileage_km;
