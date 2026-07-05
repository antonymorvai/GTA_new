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
| `security.anticheat` | Anti-Cheat-Detection (Phase 6) | `{check:'teleport'\|'health_range'\|'armor_range'\|'blacklisted_entity'\|'explosion', detail, strikes}` |

### system.* (implementiert, Basis)
| Typ | Trigger | Payload |
|---|---|---|
| `system.resource_start` / `system.resource_stop` | Ressourcen-Lifecycle | `{resource}` |
| `system.error` | Server-seitiger Fehler | `{resource, message, stack?}` |

### config.* (implementiert, Phase 2)
| Typ | Trigger | Payload |
|---|---|---|
| `config.change` | Tuning-Flag geändert (ACP/Konsole) | `{key, before, after}` — Rollback = alten Wert erneut setzen |

### economy.* (implementiert, Phase 2)
| Typ | Trigger | Payload |
|---|---|---|
| `economy.price_tick` | Preis-Tick mit mind. einer Änderung | `{changes:[{shop, region, item, before, after, stock}]}` |

### job.* (implementiert, Phase 2)
| Typ | Trigger | Payload |
|---|---|---|
| `job.assign` | Job gesetzt/gewechselt | `{characterId, before?, after:{job,grade}, byAccountId?}` |
| `job.duty` | Dienst an/aus | `{characterId, job, onDuty}` |
| `job.payroll` | Lohnlauf abgeschlossen | `{paidCount, multiplier}` — Einzelzahlungen als money.create(state.salary) mit gleicher correlationId |

### bank.* (implementiert, Phase 2 — Zahlungen selbst sind money.*)
| Typ | Trigger | Payload |
|---|---|---|
| `bank.standing_order_create` | Dauerauftrag angelegt | `{orderId, toAccountNumber, amount, intervalHours}` |
| `bank.standing_order_failed` | Ausführung gescheitert (pausiert) | `{orderId, error}` |

### vehicle.* (implementiert, Phase 2 — Basis)
| Typ | Trigger | Payload |
|---|---|---|
| `vehicle.buy` | Kauf beim Händler (money-korreliert) | `{vehicleId, plate, model, price, ownerId}` |
| `vehicle.spawn` / `vehicle.store` | Garage aus-/eingeparkt | `{vehicleId, plate, garage, fuel?, mileageKm?}` |
| `vehicle.enter` / `vehicle.exit` | Ein-/Aussteigen (server-validiert) | `{plate, seat:'driver'\|'passenger'}` |
| `vehicle.key_grant` | Schlüsselübergabe | `{vehicleId, plate, fromCharacterId, toCharacterId}` |
| `vehicle.refuel` | Tanken (money-Event vorgelagert) | `{vehicleId, plate, liters, cost, fuelBefore, fuelAfter}` |

### comms.* (SMS implementiert, Phase 2)
| Typ | Trigger | Payload |
|---|---|---|
| `comms.sms` | SMS versendet | `{fromNumber, toNumber, body}` — Inhalt voll geloggt (Katalog §2.2) |

### combat.* (implementiert, Phase 3)
| Typ | Trigger | Payload |
|---|---|---|
| `combat.damage` | Jeder Waffenschaden (weaponDamageEvent, server-seitig) | `{weaponHash, damage, zone, hitComponent, distance, targetCharacterId?, targetType}` |
| `combat.down` | Spieler bewusstlos/tot | `{characterId, cause, weaponHash?, killerCharacterId?, killerAccountId?, bleedOutSeconds}` — Kill-Akte = dieses Event + position_samples der letzten 60 s |

### medical.* (implementiert, Phase 3)
| Typ | Trigger | Payload |
|---|---|---|
| `medical.revive` / `medical.treat` / `medical.diagnose` | EMS-Aktionen (Diagnose = Akteneinsicht, wird geloggt!) | `{patientCharacterId, medicCharacterId, injuriesTreated?}` |

### police.* (implementiert, Phase 3)
| Typ | Trigger | Payload |
|---|---|---|
| `police.mdt_access` | JEDER MDT-Zugriff, auch reines Nachschlagen | `{view:'person'\|'vehicle'\|'evidence'\|'weapon_serial', officerCharacterId, targetCharacterId?, query}` |
| `police.charge` | Strafregister-Eintrag | `{targetCharacterId, lawCode, officerCharacterId, note}` |
| `police.warrant` | Fahndung ausgeschrieben/geschlossen | `{warrantId, targetCharacterId?, reason?, status, issuedByCharacterId?/closedByCharacterId?}` |

### evidence.* (implementiert, Phase 3 — Chain of Custody)
| Typ | Trigger | Payload |
|---|---|---|
| `evidence.case_open` | Fall angelegt | `{caseNumber, title, byCharacterId}` |
| `evidence.custody` | Ein-/Auslagerung von Beweismitteln (zusätzlich zu item.move) | `{caseNumber, itemUuid, action:'stored'\|'checked_out'\|'returned', byCharacterId, note}` |

### law.* / justice.* (implementiert, Phase 3)
| Typ | Trigger | Payload |
|---|---|---|
| `law.change` | Gesetz geändert (Version-Bump + Snapshot in law_history) | `{code, version, before:{fine,jailMinutes}, after:{...}, changedByCharacterId}` |
| `justice.fine` / `justice.fine_paid` | Bußgeld ausgestellt / bezahlt (Zahlung = money.destroy(fine.payment), korreliert) | `{fineId, lawCode, amount, targetCharacterId?, issuedByCharacterId?}` |
| `justice.jail` / `justice.release` | Haft angetreten / Entlassung | `{sentenceId, targetCharacterId?, minutes?, reason, issuedByCharacterId?/releasedByCharacterId?}` |

### vehicle.repair (implementiert, Phase 3)
| Typ | Trigger | Payload |
|---|---|---|
| `vehicle.repair` | Werkstatt-Reparatur (kein Auto-Heal!) | `{plate, mechanicCharacterId, engineBefore, engineAfter}` |

### skill.* (implementiert, Phase 4)
| Typ | Trigger | Payload |
|---|---|---|
| `skill.level_up` | Level-Aufstieg durch Nutzungs-XP | `{characterId, skill, levelBefore, levelAfter, xp}` |

### resource.* (implementiert, Phase 4)
| Typ | Trigger | Payload |
|---|---|---|
| `resource.harvest` | Abbau/Ernte (Pool-gedeckt) | `{poolId, poolType, item, yield, poolRemaining, skillLevel}` |
| `resource.depleted` | Ernteversuch an erschöpftem Pool | `{poolId, poolType, label}` |

### territory.* (implementiert, Phase 4)
| Typ | Trigger | Payload |
|---|---|---|
| `territory.influence_change` | Aktivität erhöht Einfluss | `{territoryId, gangId, activity, delta, influenceAfter}` |
| `territory.tick` | Verfalls-Tick (Snapshot aller Einflüsse) | `{decay, influence:[...]}` |

### drug.* / crime.* (implementiert, Phase 4)
| Typ | Trigger | Payload |
|---|---|---|
| `drug.process` | Verarbeitung Rohware -> Produkt (item-korreliert) | `{input, output, quantity, quality, skillLevel}` |
| `drug.sale` | NPC-Verkauf am aktiven Spot (money/item-korreliert) | `{item, quantity, quality, unitPrice, total, spotId, territoryId?, copsOnDuty, factors}` |
| `crime.trace` | Tat hinterlässt Spur (Wahrscheinlichkeit) — Täter-ID NUR im Log-Store, in-RP muss ermittelt werden | `{crime, spotId?, hint, suspectCharacterId}` |

### director.* (implementiert, Phase 4)
| Typ | Trigger | Payload |
|---|---|---|
| `director.event` | World-Director-Ereignis (auch manuell via Konsole) | `{event, success, detail, manual?}` |

### property.* / door.* (implementiert, Phase 4)
| Typ | Trigger | Payload |
|---|---|---|
| `property.buy` | Kauf (money-korreliert) | `{propertyId, label, region, price, ownerId}` |
| `property.key_grant` | Schlüssel übergeben | `{propertyId, fromCharacterId, toCharacterId}` |
| `door.access` | Zutrittsversuch MIT Berechtigungsergebnis | `{propertyId, result:'granted'\|'denied', characterId}` |

### company.* (implementiert, Phase 4 — Geldflüsse als money.transfer mit target kind 'company')
| Typ | Trigger | Payload |
|---|---|---|
| `company.create` | Handelsregister-Eintrag | `{companyId, name, label, ownerCharacterId}` |
| `company.hire` / `company.fire` | Personalie | `{companyId, characterId, salary?, byCharacterId}` |
| `company.payroll_failed` | Lohnlauf ohne Deckung | `{companyId, characterId, salary, error}` |

### web.* / anomaly.* (implementiert, Phase 5 — serverId 'web')
| Typ | Trigger | Payload |
|---|---|---|
| `web.login` | UCP/ACP-Login (Erfolg UND Fehlschlag) | `{success, username, reason?, ip}` |
| `web.mutation` | Jede UCP/ACP-Mutation (Registrierung, 2FA, Anomalie-Status, …) | `{action, ...}` |
| `admin.access` | JEDER ACP-Lesezugriff (Akte, Logs, Timeline, Replay, Tuning) | `{view, targetAccountId?, filters?, ...}` |
| `anomaly.detected` | Anomalie-Regel schlägt an (Prüf-Queue) | `{rule, total?/count?, threshold}` |

### weapon.* / combat.shot (implementiert — Waffen als Instanzen)
| Typ | Trigger | Payload |
|---|---|---|
| `weapon.equip` / `weapon.holster` | Ausrüsten/Wegstecken über das Inventar | `{uuid, item, serialNumber?, ammoLoaded?}` |
| `weapon.load` | Munitions-Item lädt die ausgerüstete Waffe | `{uuid, rounds, ammoLoaded}` |
| `combat.shot` | Schuss-Batch (client-gemeldet, server-geklemmt auf geladene Munition) | `{uuid, item, serialNumber, shots, ammoRemaining}` — erhöht shots_fired der Instanz (Ballistik für /serialcheck) |

### craft.* (implementiert)
| Typ | Trigger | Payload |
|---|---|---|
| `craft.complete` | Rezept gefertigt (Zutaten-consume + Ergebnis-create korreliert) | `{recipe, output, quantity, quality, skillLevel}` |

### weather.* / vehicle.service (implementiert)
| Typ | Trigger | Payload |
|---|---|---|
| `weather.change` | Wetterfront wechselt (Zustandsmaschine oder ACP-Override) | `{before, after, override}` |
| `vehicle.service` | Wartung (setzt Verschleiß-Intervall zurück) | `{plate, mechanicCharacterId}` |

### Reserviert für Folgephasen (Namespace fixiert, Schema folgt je Modul)
`combat.kill_file` (aggregierte Kill-Akte) ·
`vehicle.lock/unlock/tune/damage` · `comms.chat/call_meta/call_content/radio/tweet/ad` ·
`law.vote` (Gesetzgebungs-Workflow der Regierung)

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
