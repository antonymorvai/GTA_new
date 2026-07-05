# web — Homepage, UCP & ACP (Next.js)

Next.js-App (App Router, Tailwind, Dark-Design):

- **Homepage:** Landing mit Feature-Übersicht, Regelwerk, Impressum/Datenschutz
  (DSGVO-Texte vor Livegang mit Betreiberdaten befüllen).
- **Auth:** Registrierung (Argon2id im Backend), Login mit optionalem TOTP-2FA.
- **UCP** (`/ucp`): Dashboard (Charaktere, Vermögen, Spielzeit, Whitelist-Status),
  Kontoauszug je Charakter — vollständig aus dem Log-Store generiert.
- **ACP** (`/acp`, RBAC-geprüft, jeder Zugriff auditiert):
  - Spieler-Suche + 360°-Akte (Charaktere, Identifier, Fahrzeuge, Immobilien, Sanktionen)
  - Log-Explorer (kombinierbare Filter, Korrelations-Drill-Down)
  - Item-Trace (Besitzkette als Zeitstrahl) + Geldfluss-Analyse (n Hops, aggregiert)
  - Anomalie-Prüf-Queue (Übernehmen/Erledigen mit Begründungspflicht)
  - Live-Tuning-Editor mit Änderungs-Historie (Rollback = alten Wert speichern)

## Entwicklung

```bash
npm install
INTERNAL_API_URL=http://localhost:3001 npm run dev
```

Produktion: läuft als Container hinter Caddy (`/` → web, `/api` → backend).

## Bewusste Ausbaustufen
Whitelist-Fragebogen, Ticketsystem, Fraktionsverwaltung, Wahlen, Galerie/News-CMS,
Session-Replay-Kartenansicht und die interaktive Geldfluss-Graph-Visualisierung
setzen auf den vorhandenen APIs auf (Replay-/Flow-Daten liefert das Backend bereits).
