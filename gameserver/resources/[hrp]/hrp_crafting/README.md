# hrp_crafting

Crafting mit **Rezepten als DB-Daten** (`crafting_recipes`, zur Laufzeit
nachladbar) und **Skill-Freischaltung**: `/rezepte` zeigt Verfügbarkeit,
`/craft <name>` sammelt Zutaten über Instanzen hinweg ein (`PlanInputs`,
pure + getestet), fertigt mit Skill-abhängiger Qualität und vergibt XP nur
bei Erfolg. Alles unter einer correlationId (`item.consume`* + `item.create`
+ `craft.complete`).

Seeds: Verband (Stoff), Dietrich (Metallteile, Lv 2), Reparatur-Kit (Lv 3);
Materialien im Shop-Sortiment.

DoD: 1 ✅ (pure Logik unit-getestet) 2 ✅ 3 ✅ (Rezepte = Daten) 4 ✅ 5 ✅ —
Werkzeug-Pflicht/-Verschleiß und ortsgebundene Werkbänke sind vorgesehene
Ausbaustufen (Spalte/Feld je Rezept ergänzbar).
