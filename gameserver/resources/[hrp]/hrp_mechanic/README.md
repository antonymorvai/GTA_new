# hrp_mechanic

Mechaniker: Fahrzeug-Reparatur (**kein Auto-Heal** — beschädigte Fahrzeuge
werden ausschließlich hier repariert, geloggt als `vehicle.repair` mit
Vorher/Nachher) und generisches Rechnungssystem: `/bill` stellt eine Rechnung,
der Kunde bestätigt mit `/paybill` → `money.transfer(invoice.payment)`.
Rechnungen verfallen nach 5 Minuten; Betrags-Deckel per Tuning.

## Befehle
Mechaniker (im Dienst): `/repair` · `/bill <id> <€> [notiz]`
Kunde: `/paybill`

## Live-Tuning
`mechanic.max_bill_cents` (100000000)

## Definition of Done (Phase-3-Scope)
1. Lauffähig ✅ 2. vehicle.repair + money.transfer ✅ 3. Tuning ✅
4. ACP-Datenbasis ✅ 5. Doku ✅ — Werkstatt-Zonen, Teileverbrauch,
Abschleppdienst und Tuning folgen Phase 4.
