# hrp_director

World Director: erzeugt gewichtete Zufallsereignisse ohne Admin-Eingriff —
Deal-Spot-Rotation, Ressourcen-Booms, Verkehrsunfälle mit Dispatch an
Polizei/Rettung. Jedes Ereignis wird als `director.event` geloggt.

**Live steuerbar:** `director.enabled` (true) · `director.tick_minutes` (20) ·
`director.weight_<event>` (Gewicht 0 = Ereignis aus). Manuell testen:
Konsole `hrp_director_fire <event>`.

Neue Ereignisse registrieren sich in der Registry in `server/main.lua`
(Brände, Stromausfälle, Geldtransporte, Seuchen folgen in Ausbaustufen).

DoD: 1 ✅ 2 ✅ 3 ✅ (Frequenz/Gewichte live) 4 ✅ 5 ✅
