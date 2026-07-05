# hrp_drugs

Mehrstufige illegale Kette (Referenz: Cannabis):
1. **Beschaffung:** `weed_raw` über den Farming-Pool (hrp_resources).
2. **Verarbeitung:** `/process` an der Location — Qualität skaliert mit
   Crafting-Skill, `drug.process` item-korreliert.
3. **Vertrieb:** `/sellweed <uuid>` nur an **aktiven, rotierenden Deal-Spots**
   (Director rotiert). Preis = Basis × Qualität × Territoriums-Modifikator ×
   Cop-Skalierung. Jeder Verkauf erzeugt mit Wahrscheinlichkeit eine **Spur**
   (`crime.trace` — Täter-ID nur im Log-Store, in-RP muss ermittelt werden)
   und ggf. einen Polizei-Dispatch. Deals geben Territoriums-Einfluss.

Tuning: `drugs.weed_base_price` (4500) · `process_batch_size` (5) ·
`active_spots` (2) · `min_cops` (0) · `cop_price_bonus` (0.05) ·
`trace_chance_base` (0.15) · `trace_chance_per_cop` (0.02) · `dispatch_chance` (0.5).

DoD: 1 ✅ 2 ✅ (alle Stufen korreliert geloggt) 3 ✅ 4 ✅ 5 ✅ —
Streckung/Toleranz/Sucht, weitere Ketten und Polizeipräsenz-Heatmap-Gewichtung
der Spots folgen später.
