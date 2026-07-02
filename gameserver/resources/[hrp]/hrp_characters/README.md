# hrp_characters

Multi-Charakter-System: 3 Slots (Convar `hrp_character_slots`), Erstellung mit
Pflicht-Lebenslauf (min. 200 Zeichen), server-validierte Namen/Alter,
NUI-Auswahl, Soft-Delete, periodischer Save, Disconnect-Save.

## Tabellen
`characters`, `character_vitals`, `character_skills` (+ `character_money` via hrp_core).

## Events (Log-Katalog)
`character.create`, `character.delete`, `character.spawn`, `character.save`,
`session.character_select`. Startgeld läuft als `money.create` mit derselben
`correlationId` wie `character.create`.

## Convars
| Convar | Default | |
|---|---|---|
| `hrp_character_slots` | 3 | Slots pro Account |
| `hrp_character_save_interval` | 60000 | Save-Zyklus ms |
| `hrp_starter_cash` | 50000 | Startgeld in Cent |

## Hinweis Charakter-Events
Die Events dieses Moduls laufen bewusst VOR der Charakterwahl und nutzen daher
manuelle Validierung statt `RegisterSecureEvent` (das Charakter-Pflicht kennt).
Besitz-Prüfung (Charakter ↔ Account) erfolgt bei jeder Operation serverseitig.

## Definition of Done (Phase-1-Scope)
1. Lauffähig ✅  2. Alle Mutationen erzeugen Katalog-Events ✅
3. Balancing via Convars (ACP-Live-Tuning Phase 2) ✅
4. ACP-Ansicht Phase 5 (Datenbasis vollständig) ✅  5. Doku ✅

Vitals-Simulation (Hunger/Durst-Tick, Temperatur) und Verletzungssystem folgen
in Phase 2/3 — die Datenstruktur (`character_vitals`) steht bereits.
