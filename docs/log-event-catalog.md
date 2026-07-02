# Log-Event-Katalog v1

**Kernprinzip A: Totale Nachverfolgbarkeit.** Jede zustandsändernde Aktion erzeugt
ein unveränderliches Event. Dieses Dokument ist der verbindliche Vertrag zwischen
Gameserver, Log-Pipeline und ACP. **Kein Modul gilt als fertig, dessen Mutationen
nicht vollständig in diesem Katalog stehen** (Definition of Done, Regel 2).

## 1. Envelope (alle Events)

Jedes Event ist ein JSON-Objekt mit diesem Umschlag. Pflichtfelder sind markiert.

```jsonc
{
  "eventId": "6f1c2a9e-...",          // UUID v4, vom Erzeuger generiert   [Pflicht]
  "ts": 1751490000123,                 // Unix-ms, Serverzeit               [Pflicht]
  "type": "money.transfer",           // Namespace.Aktion                   [Pflicht]
  "schemaVersion": 1,                  //                                    [Pflicht]
  "serverId": "main",
  "actor": {                           // Wer hat gehandelt (null = System)
    "accountId": 42,
    "characterId": 1337,
    "sessionId": "a1b2c3d4-..."
  },
  "target": { "kind": "character", "id": "2001" },   // Wen/was betrifft es
  "context": {
    "pos": { "x": 215.3, "y": -810.1, "z": 30.7 },
    "instance": null                   // Interior-/Routing-Instanz
  },
  "correlationId": "9e8d7c6b-...",    // verkettet Multi-Event-Transaktionen
  "payload": { }                       // typ-spezifisch, siehe unten       [Pflicht]
}
```

**Korrelations-Regel:** Jede zusammengesetzte Transaktion (z. B. Fahrzeugkauf =
Geld-Event Käufer + Geld-Event Verkäufer + Eigentums-Event + Steuer-Event) trägt
dieselbe `correlationId`. Der Erzeuger holt sie über `exports.hrp_logger:NewCorrelationId()`.

**Vorher/Nachher-Regel:** Payloads von Zustandsänderungen enthalten `before` und
`after` (oder `delta` + `balanceAfter` bei Geld), damit das ACP jede Änderung ohne
Rekonstruktion anzeigen kann.

## 2. Kategorien & Event-Typen (v1 — Phase 1 implementiert, Rest reserviert)

### session.* (implementiert)
| Typ | Trigger | Payload |
|---|---|---|
| `session.connect` | Spieler verbindet (nach Ban-/Whitelist-Check) | `{ip, identifiers: {license, discord?, hwidHash}, queueTimeMs}` |
| `session.drop` | Verbindung endet | `{reason, durationSec}` |
| `session.character_select` | Charakterwahl | `{characterId, slot}` |

Beispiel:
```json
{"eventId":"...","ts":1751490000123,"type":"session.connect","schemaVersion":1,
 "actor":{"accountId":42,"sessionId":"a1b2..."},
 "payload":{"ip":"203.0.113.7","identifiers":{"license":"license:abc"},"queueTimeMs":1200}}
```

### character.* (implementiert)
| Typ | Trigger | Payload |
|---|---|---|
| `character.create` | Charakter erstellt | `{characterId, slot, firstName, lastName, dateOfBirth, gender}` |
| `character.delete` | Soft-Delete | `{characterId, slot}` |
| `character.spawn` | Spawn in Welt | `{characterId, pos}` |
| `character.state_change` | alive/unconscious/dead/ck | `{characterId, before, after, cause?}` |
| `character.save` | periodischer Save | `{characterId, pos, vitals}` |

### money.* (Katalog fixiert; Engine in Phase 2, Basis-API in Phase 1 aktiv)
**Invariante: Kein Cent entsteht oder verschwindet ohne Event mit `reason`-Code.**
| Typ | Trigger | Payload |
|---|---|---|
| `money.create` | Geld entsteht (Quelle: Staat, Systemverkauf, Admin) | `{account:"cash"\|"bank", amount, reason, balanceAfter}` |
| `money.destroy` | Geld versinkt (Steuer, Gebühr, Konsum an System) | `{account, amount, reason, balanceAfter}` |
| `money.transfer` | Spieler↔Spieler / Konto↔Konto | `{from:{characterId,account}, to:{characterId,account}, amount, reason, fromBalanceAfter, toBalanceAfter}` |
| `money.adjust` | Admin-Eingriff | `{account, before, after, reason, adminAccountId}` |

`reason`-Codes sind registriert (siehe `hrp_core/shared/reasons.lua`); unbekannte
Codes werden vom Core abgelehnt — verhindert „anonymes" Geld.

### item.* (implementiert)
Jede Instanz hat eine `uuid`; `target` ist immer `{kind:"item", id:"<uuid>"}`.
| Typ | Trigger | Payload |
|---|---|---|
| `item.create` | Instanz erzeugt | `{uuid, definition, quantity, quality?, serialNumber?, reason, container}` |
| `item.move` | Lagerbewegung (Inventar↔Kofferraum↔Boden↔Lager) | `{uuid, from:{type,id}, to:{type,id}}` |
| `item.transfer` | Besitzerwechsel Spieler→Spieler | `{uuid, fromCharacterId, toCharacterId, quantity}` |
| `item.modify` | Metadaten/Qualität geändert | `{uuid, before, after, reason}` |
| `item.consume` | Verbrauch (Teilmenge möglich) | `{uuid, quantityConsumed, quantityAfter}` |
| `item.destroy` | Zerstörung | `{uuid, reason}` |

### position.* (implementiert)
| Typ | Trigger | Payload |
|---|---|---|
| `position.batch` | Sampler (Standard alle 5 s, konfigurierbar) | `{samples:[{characterId, sessionId, x,y,z, heading, speed}]}` |

Wird vom Backend in die Tabelle `position_samples` entrollt → Bewegungs-Replay.

### rbac.* (implementiert)
| Typ | Trigger | Payload |
|---|---|---|
| `rbac.role_grant` / `rbac.role_revoke` | Rollenzuweisung | `{accountId, role, byAccountId}` |

### admin.* (implementiert, Basis)
**Jede Admin-Aktion — auch reines ANSCHAUEN sensibler Daten — wird geloggt.**
| Typ | Trigger | Payload |
|---|---|---|
| `admin.action` | Teleport, Item-Give, Geld-Set, Kick, Ban, … | `{action, targetAccountId?, targetCharacterId?, args, permission}` |
| `admin.access` | Lesezugriff auf sensible Daten (Akte, Logs, Inventar) | `{view, targetAccountId?, filters?}` |

### security.* (implementiert, Basis)
| Typ | Trigger | Payload |
|---|---|---|
| `security.rate_limit` | Spieler überschreitet Event-Rate | `{eventName, allowedPerSec, observed}` |
| `security.invalid_event` | Ungültige/abgelehnte Event-Argumente | `{eventName, violation}` |
| `security.ban` | Ban ausgesprochen | `{banId, reason, expiresAt, byAccountId}` |

### system.* (implementiert, Basis)
| Typ | Trigger | Payload |
|---|---|---|
| `system.resource_start` / `system.resource_stop` | Ressourcen-Lifecycle | `{resource}` |
| `system.error` | Server-seitiger Fehler | `{resource, message, stack?}` |

### Reserviert für Folgephasen (Namespace fixiert, Schema folgt je Modul)
`combat.shot`, `combat.damage`, `combat.down`, `combat.kill_file` ·
`vehicle.enter/exit/lock/unlock/key_transfer/tune/damage/odometer` ·
`comms.chat/sms/call_meta/tweet/ad` · `door.access` · `web.login/mutation` ·
`economy.price_tick` · `director.event` · `law.change` · `territory.tick`

## 3. Zustellgarantie

1. Erzeuger (Lua) ruft `exports.hrp_logger:Log(type, data)` → Event landet in
   In-Memory-Queue (nicht blockierend).
2. Flush alle 2 s oder ab 100 Events: HTTP-POST-Batch an Backend
   `/v1/ingest/events` (nur internes Netz, Bearer-Token).
3. Backend validiert (zod) und schreibt in Redis Stream `hrp:events`.
4. Consumer (Backend) liest per Consumer-Group, Batch-Insert in TimescaleDB,
   dann `XACK`. Fehlerhafte Events → Dead-Letter-Stream `hrp:events:dead`.
5. **Ausfallsicherheit:** Schlägt der HTTP-Flush fehl, schreibt der Logger die
   Batches als JSON-Lines auf Disk (`buffer/`) und spielt sie beim nächsten
   erfolgreichen Flush nach. Kein Log-Verlust bei Queue-/Backend-Ausfall.

## 4. Versionierung & Erweiterung

- Neue Events: Eintrag hier **vor** Implementierung (Trigger, Payload-Schema, Beispiel).
- Breaking Changes an Payloads: `schemaVersion` erhöhen, alte Version im ACP weiter lesbar.
- Retention: `LOG_RETENTION_DAYS` (Default 90) / `POSITION_RETENTION_DAYS` (Default 30);
  Löschung via Timescale-Retention-Policy, DSGVO-Einzelfall-Löschung siehe `docs/operations.md`.
