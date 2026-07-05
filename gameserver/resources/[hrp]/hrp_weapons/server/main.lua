--[[
    hrp_weapons – Waffen sind Item-Instanzen mit Seriennummer:

    - AUSRÜSTEN über das Inventar (hrp:items:equip aus hrp_inventory):
      Ped bekommt die Waffe mit der GELADENEN Munition der Instanz
      (metadata.ammo_loaded) — Waffen entstehen nie aus dem Nichts.
    - MUNITION: Munitions-Items laden beim Benutzen die ausgerüstete Waffe
      (Verbrauch = item.consume, Ladung = item.modify, weapon.load-Event).
    - SCHUSSZÄHLER: Client meldet Schüsse gebatcht; der Server validiert
      (ausgerüstet? plausible Anzahl?), zählt shots_fired der Instanz hoch,
      zieht geladene Munition ab und loggt combat.shot — die Ballistik-Spur
      für /serialcheck und die Kill-Akte.
    - Beim Ablegen/Weggeben/Einlagern der Instanz wird die Waffe automatisch
      entzogen (Besitz = Trageberechtigung).
]]

local Core = exports.hrp_core
local Inv = exports.hrp_inventory

-- Waffen-Registry: Item-Name -> Engine-Waffe + Munitions-Item + Schuss/Ladung
local WEAPONS = {
    weapon_pistol = { hash = 'WEAPON_PISTOL', ammoItem = 'ammo_9mm', roundsPerUnit = 12, magSize = 60 },
}

-- equipped[src] = { uuid, itemName, hash }
local equipped = {}

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2WAFFE' or '^1WAFFE', msg } })
end

local function loadedAmmo(uuid)
    local meta = Inv:GetInstanceMeta(uuid)
    return meta and tonumber(meta.metadata.ammo_loaded) or 0, meta
end

local function holster(src, silent)
    local current = equipped[src]
    if not current then return end
    equipped[src] = nil
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        RemoveWeaponFromPed(ped, joaat(current.hash))
    end
    Core:Log(src, 'weapon.holster', {
        target = { kind = 'item', id = current.uuid },
        payload = { uuid = current.uuid, item = current.itemName },
    })
    if not silent then reply(src, true, 'Waffe weggesteckt.') end
end

-- Ausrüsten/Wegstecken über das Inventar ("Benutzen" auf einer Waffe)
AddEventHandler('hrp:items:equip', function(src, itemName, uuid)
    local def = WEAPONS[itemName]
    if not def then return reply(src, false, 'Diese Waffe wird noch nicht unterstützt.') end

    -- Toggle: gleiche Instanz -> wegstecken
    if equipped[src] and equipped[src].uuid == uuid then
        return holster(src)
    end
    if equipped[src] then holster(src, true) end

    local ammo, meta = loadedAmmo(uuid)
    if not meta then return end

    local ped = GetPlayerPed(src)
    GiveWeaponToPed(ped, joaat(def.hash), ammo, false, true)
    equipped[src] = { uuid = uuid, itemName = itemName, hash = def.hash }

    Core:Log(src, 'weapon.equip', {
        target = { kind = 'item', id = uuid },
        payload = { uuid = uuid, item = itemName, serialNumber = meta.serialNumber, ammoLoaded = ammo },
    })
    TriggerClientEvent('hrp:weapons:equipped', src, true)
    reply(src, true, ('%s gezogen (%d Schuss geladen).'):format(itemName, ammo))
end)

-- Munition laden (Munitions-Item benutzt)
AddEventHandler('hrp:items:used', function(src, itemName)
    local current = equipped[src]
    if not current then return end
    local def = WEAPONS[current.itemName]
    if not def or def.ammoItem ~= itemName then return end

    local ammo = loadedAmmo(current.uuid)
    local newAmmo = math.min(def.magSize, ammo + def.roundsPerUnit)
    Inv:Modify(current.uuid, { metadata = { ammo_loaded = newAmmo } }, 'weapon.load', { srcForLog = src })

    local ped = GetPlayerPed(src)
    SetPedAmmo(ped, joaat(current.hash), newAmmo)

    Core:Log(src, 'weapon.load', {
        target = { kind = 'item', id = current.uuid },
        payload = { uuid = current.uuid, rounds = newAmmo - ammo, ammoLoaded = newAmmo },
    })
    reply(src, true, ('Nachgeladen: %d Schuss im Magazin.'):format(newAmmo))
end)

-- Schuss-Batches vom Client (validiert + geklemmt)
Core:RegisterSecureEvent('hrp:weapons:shots', {
    rate = 0.5, burst = 3,
    schema = { { type = 'number', integer = true, min = 1, max = 60 } },
}, function(src, count)
    local current = equipped[src]
    if not current then
        Core:Log(src, 'security.invalid_event', {
            payload = { eventName = 'hrp:weapons:shots', violation = 'no_weapon_equipped' },
        })
        return
    end

    local ammo = loadedAmmo(current.uuid)
    local shots = math.min(count, ammo)   -- nie mehr Schüsse als geladen
    if shots < 1 then return end

    Inv:AddShots(current.uuid, shots)
    Inv:Modify(current.uuid, { metadata = { ammo_loaded = ammo - shots } }, 'weapon.shots', { srcForLog = src })

    local meta = Inv:GetInstanceMeta(current.uuid)
    Core:Log(src, 'combat.shot', {
        target = { kind = 'item', id = current.uuid },
        payload = { uuid = current.uuid, item = current.itemName,
                    serialNumber = meta and meta.serialNumber, shots = shots,
                    ammoRemaining = ammo - shots },
    })
end)

-- Besitzverlust = Waffe weg: Ablegen/Geben/Einlagern der ausgerüsteten Instanz
AddEventHandler('hrp:inventory:instanceMoved', function(uuid)
    for src, current in pairs(equipped) do
        if current.uuid == uuid then
            holster(src, true)
            reply(src, false, 'Deine Waffe hat den Besitzer gewechselt.')
        end
    end
end)

AddEventHandler('playerDropped', function()
    equipped[source] = nil
end)

exports('GetEquipped', function(src) return equipped[src] end)
