# hrp_banking

Bank: Kontonummern (`LSxxxxxxxx`, lazy vergeben), Ein-/Auszahlung und
Überweisungen **nur an Bank-/ATM-Standorten** (server-seitig geprüft),
Daueraufträge mit automatischer Ausführung (bei fehlender Deckung pausiert +
`bank.standing_order_failed`).

Alle Zahlungen laufen über die Core-Geld-API → `money.*`-Events mit
`bank.deposit/withdraw/transfer/standing_order`-Reasons; Kontoauszüge fürs UCP
werden vollständig aus dem Log-Store generiert.

## Befehle
`/balance` · `/deposit <€>` · `/withdraw <€>` · `/transfer <konto> <€>` ·
`/dauerauftrag <konto> <€> <stunden>` (· `/duty` liegt hier im Client für hrp_jobs)

## Live-Tuning
`banking.location_radius` (10.0)

## Definition of Done (Phase-2-Scope)
1. Lauffähig ✅ 2. Alle Mutationen als money.*/bank.* ✅ 3. Tuning ✅
4. ACP-Datenbasis (money_flow_daily-Aggregat) ✅ 5. Doku ✅ —
Kredite, Pfändung, Schließfächer folgen mit der Justiz (Phase 3).
