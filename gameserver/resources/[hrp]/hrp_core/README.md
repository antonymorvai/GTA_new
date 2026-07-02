# hrp_core

Framework-Kern: Accounts & Sessions, Event-Security, RBAC, Geld-Basis-API,
Admin-Basis-Befehle. Alle anderen Module bauen hierauf auf.

## Server-Exports

| Export | Beschreibung |
|---|---|
| `GetPlayerIdentity(src)` | `{accountId, characterId, sessionId}` oder `nil` |
| `SetCharacter(src, characterId)` | Charakter an Session binden (nur hrp_characters) |
| `Log(src, type, data)` | Log mit automatischem actor/pos aus der Registry |
| `HasPermission(src, perm)` | RBAC-Prüfung (gecacht pro Session) |
| `GrantRole(accountId, role, byAccountId)` / `RevokeRole(...)` | Rollenverwaltung, geloggt |
| `MoneyCreate/MoneyDestroy/MoneyTransfer/MoneyGetBalance` | Geld-API (siehe unten) |

## Geld-Invariante

Salden: `character_money` (Cent, Integer). **Jede** Änderung läuft über
`HRP.Money.*` — die API koppelt Saldo-Update und `money.*`-Event und lehnt
unbekannte `reason`-Codes ab (`shared/reasons.lua`). Direkte UPDATEs auf
`character_money` sind ein Review-Blocker.

## Abgesicherte Events

`HRP.RegisterSecureEvent(name, opts, handler)` erzwingt: Session-Bindung,
optional Charakter-Pflicht, Rate-Limit (Token-Bucket), Argument-Schema,
optionale RBAC-Permission. Verstöße → `security.*`-Events.

```lua
HRP.RegisterSecureEvent('hrp:beispiel:kaufen', {
    rate = 1, burst = 3,
    schema = { { type = 'string', maxLen = 64, pattern = '^[%w_]+$' } },
}, function(src, itemName) ... end)
```

## Admin-Befehle (Phase 1)

`/goto`, `/givemoney`, `/kick`, `/ban` — RBAC-geprüft, jede Nutzung erzeugt
`admin.action`. Rollen-Bootstrap über txAdmin-Konsole:
`hrp_grantrole <accountId> admin`.

## Definition of Done (Phase-1-Scope)

1. Lauffähig ✅  2. Alle Mutationen (Geld, Rollen, Bans, Sessions) erzeugen
Katalog-Events ✅  3. Balancing-Werte: Rate-Limits/Whitelist via Convar,
ACP-Live-Tuning folgt Phase 2 ✅  4. ACP-Ansicht folgt Phase 5 (Datenbasis
vollständig) ✅  5. Doku ✅
