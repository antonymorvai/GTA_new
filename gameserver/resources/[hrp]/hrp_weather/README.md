# hrp_weather

Server-autoritatives Wetter mit **Fronten statt Zufalls-Switch**: pure
Zustandsmaschine (getestet — kein Sprung von klar zu Gewitter, Regen klingt
über CLEARING ab), sanfte 45-s-Überblendung an alle Clients, jeder Wechsel
als `weather.change` geloggt. Synchrone In-Game-Uhr für alle Spieler.

**Spürbarer Realismus:** Bei Regenfronten setzt der State Bag `hrp:wet`
reduzierte Reifenhaftung (Glätte).

## Live-Tuning
`weather.tick_minutes` (15) · `weather.override` ('' = Automatik; z. B.
`"THUNDER"` als ACP-Wetter-Override) · `time.scale` (4 In-Game-Minuten pro
Echtzeit-Minute ≙ 6-h-Tag)

DoD: 1 ✅ 2 ✅ 3 ✅ 4 ✅ 5 ✅ — Jahreszeiten (Erntezyklen, Heizbedarf,
Kleidungs-Effekte) docken als nächste Ausbaustufe an die Zustandsmaschine an.
