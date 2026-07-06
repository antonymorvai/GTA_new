--[[
    hrp_interact – universelles Kontext-Interaktions-System.

    Andere Ressourcen registrieren Interaktionspunkte:
      exports.hrp_interact:AddZone(id, {x,y,z}, radius, label, options)
      exports.hrp_interact:AddVehicleOption(id, label, options, canShow)
    options = { { label=, event=, server=bool, args=, canShow=fn } ... }

    Ablauf: Der nächste Zonen-/Fahrzeug-Kontext in Reichweite zeigt einen
    dezenten Prompt „[E] <Label>". [E] öffnet das Options-Menü (NUI); Auswahl
    feuert das konfigurierte Client-/Server-Event. Alle /commands bleiben als
    Fallback erhalten — dies ist die moderne, immersive Alternative.
]]

Interact = { zones = {}, vehicleOptions = {} }

local menuOpen = false
local activeContext = nil    -- { label, options }

-- Registrierungs-Exports
function Interact.AddZone(id, coords, radius, label, options)
    Interact.zones[id] = {
        coords = vector3(coords.x, coords.y, coords.z),
        radius = radius or 2.0, label = label, options = options,
    }
end

function Interact.AddVehicleOption(id, label, options, canShow)
    Interact.vehicleOptions[id] = { label = label, options = options, canShow = canShow }
end

exports('AddZone', function(...) Interact.AddZone(...) end)
exports('AddVehicleOption', function(...) Interact.AddVehicleOption(...) end)
exports('RemoveZone', function(id) Interact.zones[id] = nil end)

local function visibleOptions(options)
    local out = {}
    for _, opt in ipairs(options) do
        if not opt.canShow or opt.canShow() then
            out[#out + 1] = opt
        end
    end
    return out
end

-- Nächsten Kontext ermitteln (Zonen zuerst, dann Blick-Fahrzeug)
local function resolveContext(playerCoords)
    local best, bestDist = nil, math.huge
    for _, zone in pairs(Interact.zones) do
        local d = #(playerCoords - zone.coords)
        if d <= zone.radius and d < bestDist then
            local opts = visibleOptions(zone.options)
            if #opts > 0 then best, bestDist = { label = zone.label, options = opts }, d end
        end
    end
    if best then return best end

    -- Fahrzeug im Blick / in Nähe
    local ped = PlayerPedId()
    local veh = 0
    if IsPedInAnyVehicle(ped, false) then
        veh = GetVehiclePedIsIn(ped, false)
    else
        local hit, _, _, _, entity = GetShapeTestResult(StartShapeTestRay(
            GetEntityCoords(ped),
            GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0),
            10, ped, 0))
        if entity and entity ~= 0 and IsEntityAVehicle(entity) then veh = entity end
    end
    if veh ~= 0 then
        local merged = {}
        for _, def in pairs(Interact.vehicleOptions) do
            if not def.canShow or def.canShow(veh) then
                for _, opt in ipairs(def.options) do merged[#merged + 1] = opt end
            end
        end
        if #merged > 0 then return { label = 'Fahrzeug', options = merged, vehicle = veh } end
    end
    return nil
end

-- Haupt-Loop: Kontext-Erkennung + Prompt
CreateThread(function()
    while true do
        local sleep = 250
        if not menuOpen then
            local ctx = resolveContext(GetEntityCoords(PlayerPedId()))
            if ctx then
                sleep = 0
                activeContext = ctx
                SendNUIMessage({ action = 'prompt', label = ctx.label })
                if IsControlJustReleased(0, 38) then   -- [E]
                    menuOpen = true
                    SetNuiFocus(true, true)
                    SendNUIMessage({ action = 'menu', label = ctx.label,
                        options = (function()
                            local labels = {}
                            for i, o in ipairs(ctx.options) do labels[i] = o.label end
                            return labels
                        end)() })
                end
            else
                if activeContext then
                    activeContext = nil
                    SendNUIMessage({ action = 'clear' })
                end
            end
        end
        Wait(sleep)
    end
end)

local function runOption(opt, vehicle)
    if not opt then return end
    if opt.action then
        opt.action(vehicle)
    elseif opt.server and opt.event then
        TriggerServerEvent(opt.event, table.unpack(opt.argList or {}))
    elseif opt.event then
        local args = opt.args or {}
        if vehicle then args = { plate = GetVehicleNumberPlateText(vehicle) } end
        TriggerEvent(opt.event, args)
    end
end

RegisterNUICallback('select', function(data, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'clear' })
    local idx = tonumber(data.index)
    if activeContext and idx and activeContext.options[idx] then
        runOption(activeContext.options[idx], activeContext.vehicle)
    end
    cb({})
end)

RegisterNUICallback('cancel', function(_, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'clear' })
    cb({})
end)
