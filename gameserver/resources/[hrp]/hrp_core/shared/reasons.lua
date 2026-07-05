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
        ['drug.sale']         = true,   -- Quelle: illegaler NPC-Verkauf (Risiko/Spuren!)
        ['property.buy']      = true,   -- Senke: Immobilienkauf
        ['property.sell']     = true,   -- Quelle: Verkauf an den Staat
        ['company.deposit']   = true,   -- Transfer: Charakter -> Firmenkonto
        ['company.withdraw']  = true,   -- Transfer: Firmenkonto -> Charakter
        ['company.salary']    = true,   -- Transfer: Firmenkonto -> Mitarbeiter (Lohnlauf)
        ['loan.disbursement'] = true,   -- Quelle: Kredit-Auszahlung der Bank
        ['loan.repayment']    = true,   -- Senke: Kreditrate
        ['logistics.payment'] = true,   -- Quelle: Liefervergütung (Kraftstoff etc.)
        ['fee.classified']    = true,   -- Senke: Kleinanzeigen-Gebühr
        ['insurance.premium'] = true,   -- Senke: Versicherungsprämie
        ['insurance.payout']  = true,   -- Quelle: Versicherungsleistung
        ['insurance.deductible'] = true, -- Senke: Selbstbeteiligung Vollkasko
        ['heist.loot']        = true,   -- Quelle: Raub-Beute (illegal, massive Spuren)
        ['tax.wealth']        = true,   -- Senke: Vermögenssteuer (täglich, über Freibetrag)
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
        ['resource.harvest']  = true,   -- Quelle: Ressourcen-Abbau (Pool-gedeckt)
        ['drug.process']      = true,   -- Verarbeitung (Rohware -> Produkt)
        ['drug.sale']         = true,   -- Senke: Päckchen an NPC verkauft
    },
}

function HRPReasons.IsValid(category, code)
    local cat = HRPReasons[category]
    return cat ~= nil and cat[code] == true
end
