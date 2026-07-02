# hrp_economy

Wirtschafts-Engine: Shops mit **dynamischen Preisen** nach Angebot & Nachfrage.
Käufe senken den Bestand (Preis steigt), Verkäufe erhöhen ihn (Preis fällt);
ein periodischer Tick glättet Preise Richtung Gleichgewicht und regeneriert
Bestände (bis echte Lieferketten das in Phase 4 übernehmen).

## Preisformel
`shared/pricing.lua` — pure Funktionen, getestet via `scripts/test-lua.sh`:
Knappheit → Zielpreis → Glättung → Klemme `[base*minFactor, base*maxFactor]`.
Der Ankaufspreis liegt immer `sell_margin` unter dem Verkaufspreis, damit
Kauf-Verkauf-Schleifen nie profitabel sind.

## Transaktions-Garantie
Kauf = `money.destroy(system.buy)` + `item.create(shop.buy)` mit **derselben
correlationId**; schlägt die Item-Erzeugung fehl (z. B. Traglast), wird das
Geld mit gleicher Korrelation kompensiert — im ACP als ein Vorgang lesbar.
Verkauf analog (`item.destroy(shop.sell)` + `money.create(system.sell)`).

## Live-Tuning (config_flags, ohne Restart änderbar)
| Key | Default |
|---|---|
| `economy.price_sensitivity` | 0.6 |
| `economy.price_smoothing` | 0.25 |
| `economy.price_min_factor` / `max_factor` | 0.5 / 2.0 |
| `economy.sell_margin` | 0.3 |
| `economy.price_tick_minutes` | 15 |
| `economy.max_qty_per_purchase` | 10 |

## Events
`economy.price_tick` (alle Preisänderungen eines Ticks, mit before/after) —
Datenbasis für In-Game-Börsenticker und ACP-Wirtschafts-Dashboard.
Geld-/Item-Flüsse: `money.*`/`item.*` via Core-APIs.

## Definition of Done (Phase-2-Scope)
1. Lauffähig ✅ (Shops via Seeds, `/hrp_economy_reload`)  2. Alle Mutationen
geloggt + korreliert ✅  3. Alle Parameter live über Tuning ✅
4. ACP: money_flow_daily-Aggregat + price_tick-Events liegen bereit (UI Phase 5) ✅
5. Doku ✅
