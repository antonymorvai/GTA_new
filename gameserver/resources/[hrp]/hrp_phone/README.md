# hrp_phone

Smartphone-Basis: Rufnummer pro Charakter (lazy), Kontakte, SMS mit
Volltext-Logging (`comms.sms`). Voraussetzung für alle Funktionen: Der
Charakter trägt ein `phone`-Item — Handys sind normale Item-Instanzen und
damit stehlbar/handelbar (IMEI-Ortung folgt mit dem Justiz-Beschluss-Workflow).

## Befehle
`/mynumber` · `/sms <nummer> <text>` · `/addcontact <name> <nummer>` · `/contacts`

## Definition of Done (Phase-2-Scope)
1. Lauffähig ✅ 2. `comms.sms` vollständig ✅ 3. (keine Balancing-Werte) ✅
4. ACP-Datenbasis ✅ 5. Doku ✅ — Anrufe (Voice-Routing via SaltyChat,
`comms.call_meta`), Phone-NUI, Banking-App, Twitter-Klon und Darknet folgen
in späteren Phasen (siehe docs/voice.md).
