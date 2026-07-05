# hrp_companies

Firmen: Handelsregister (`company_register` via Konsole/Admin, UCP-Workflow
folgt), Mitglieder mit Rängen (0 Mitarbeiter / 1 Leitung / 2 Inhaber),
**Firmenkonto über die Core-Geld-API** (`MoneyCompanyTransfer` —
money.transfer-Events mit target kind 'company', Deckungs-Garantie in der DB),
automatischer Lohnlauf aus Firmenmitteln (ohne Deckung: keine Zahlung +
`company.payroll_failed`).

## Befehle
`/hire <id> <lohn€>` · `/fire <id>` (Leitung+) ·
`/companydeposit <€>` · `/companywithdraw <€>` (Leitung+) · `/companybalance`

Tuning: `companies.payroll_interval_minutes` (60).

DoD: 1 ✅ 2 ✅ (Kassenbuch = money.*-Events) 3 ✅ 4 ✅ 5 ✅ —
Zeichnungsberechtigungen, Buchhaltungspflicht-UI, Betriebsprüfung und
Insolvenz folgen mit dem UCP (Phase 5).
