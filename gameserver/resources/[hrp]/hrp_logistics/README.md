# hrp_logistics

Lieferketten mit **echtem Bedarf**: Tankstellen haben endliche Bestände
(`fuel_stations`) — Tanken zieht real ab, **leere Station verkauft nichts**,
bis ein Trucker liefert. Trucker (im Dienst) kaufen an der Palomino-Raffinerie
zum Großhandelspreis (`/loadfuel`, Bankzahlung) und verdienen an der Lieferung
die Marge (`/deliverfuel`); `/stationen` zeigt den Bedarf aller Stationen
(Stationen ≤ 15 % sind als DRINGEND markiert).

Exports für hrp_vehicles: `StationNear(x,y,z,r)`, `ConsumeStock(id, liter)`.

## Live-Tuning
`logistics.truck_capacity_l` (3000) · `logistics.wholesale_per_liter` (90 Cent) ·
`logistics.delivery_pay_per_liter` (130 Cent) — die Marge ist das Balancing.

DoD: 1 ✅ 2 ✅ (load/deliver money-korreliert, refuel trägt stationId) 3 ✅
4 ✅ 5 ✅ — weitere Ketten (Shops-Warenlieferung, Bau) docken an dasselbe Muster an.
