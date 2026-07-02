# hrp_inventory

Inventar-Basis: Item-Definitionen (DB, zur Laufzeit nachladbar) und
Item-**Instanzen** mit UUID, optionaler Seriennummer (Waffen), Qualität,
Metadaten und genau einem Aufenthaltsort (`item_locations`). Gewichtslimit
pro Charakter (Convar `hrp_max_carry_grams`, Default 30 kg).

**Lifecycle-Garantie:** Erstellen, jede Bewegung, jeder Besitzwechsel,
Verbrauch und Zerstörung laufen ausschließlich über die `Inventory.*`-API und
erzeugen `item.*`-Events → vollständiger Item-Trace im ACP. Instanzen werden
nie hart gelöscht (Soft-Delete via `destroyed_at`).

## Server-Exports
`Create(defName, qty, reason, container, opts)`, `Move(uuid, toContainer, opts)`,
`Transfer(uuid, fromCharId, toCharId, opts)`, `Consume(uuid, qty, opts)`,
`Destroy(uuid, reason, opts)`, `GetContainer(type, id)`, `GetCarryWeight(charId)`.
`reason` muss in der Reason-Registry (`hrp_core/shared/reasons.lua`) stehen.

## Client-Events (abgesichert)
`hrp:inventory:give` (Übergabe, Distanz-Check), `hrp:inventory:drop` (Boden).

## Admin
`/giveitem <serverId> <itemName> [menge]` — Permission `game.admin.item_give`,
erzeugt `admin.action` + `item.create(reason=admin.give)`.

## Definition of Done (Phase-1-Scope)
1. Lauffähig ✅  2. Alle Mutationen erzeugen Katalog-Events ✅
3. Gewichtslimit via Convar (ACP-Live-Tuning Phase 2) ✅
4. ACP-Item-Trace Phase 5 (Datenbasis vollständig) ✅  5. Doku ✅

Inventar-UI, Kofferraum-/Lager-Container-Regeln, Bodendrop-Despawn und
Durchsuchungen folgen in Phase 2.
