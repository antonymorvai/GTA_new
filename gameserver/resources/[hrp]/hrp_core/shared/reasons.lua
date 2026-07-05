--[[
    Registrierte Grund-Codes für Geld- und Item-Mutationen.
    Invariante (Event-Katalog money.*): Kein Cent entsteht/verschwindet ohne
    Event mit registriertem reason-Code. Unbekannte Codes -> Mutation abgelehnt.

    Neue Codes: hier eintragen UND im Log-Event-Katalog dokumentieren.
]]

HRPReasons = {
    money = {
        -- Quellen (money.create)
        ['state.salary']      = true,   -- staatlicher Lohn
        ['system.sell']       = true,   -- Verkauf an System-Shop
        ['admin.grant']       = true,   -- Admin-Vergabe (immer + admin.action-Event)
        ['starter.package']   = true,   -- Startgeld bei Charaktererstellung
        -- Senken (money.destroy)
        ['tax.income']        = true,
        ['fee.service']       = true,
        ['system.buy']        = true,   -- Kauf beim System-Shop
        ['admin.remove']      = true,
        -- Transfers (money.transfer)
        ['trade.direct']      = true,   -- Spieler-zu-Spieler-Übergabe
        ['bank.transfer']     = true,
        ['bank.deposit']      = true,
        ['bank.withdraw']     = true,
        ['bank.standing_order'] = true,
        ['vehicle.buy']       = true,   -- Senke: Fahrzeugkauf beim Händler
        ['vehicle.fuel']      = true,   -- Senke: Tanken
        ['fine.payment']      = true,   -- Senke: Bußgeld an den Staat
        ['invoice.payment']   = true,   -- Transfer: Rechnung Spieler->Spieler (z. B. Werkstatt)
    },
    item = {
        ['shop.buy']          = true,
        ['craft']             = true,
        ['admin.give']        = true,
        ['starter.package']   = true,
        ['job.reward']        = true,
        ['consume.use']       = true,
        ['decay.expired']     = true,
        ['admin.remove']      = true,
        ['drop.despawn']      = true,
        ['shop.sell']         = true,   -- Verkauf an System-Shop (Item-Senke)
    },
}

function HRPReasons.IsValid(category, code)
    local cat = HRPReasons[category]
    return cat ~= nil and cat[code] == true
end
