#!/usr/bin/env bash
# Log-Vollständigkeits-Audit (DoD Regel 2, statische Analyse):
#
# 1. Geschützte Tabellen (Geld-/Item-Zustand) dürfen NUR von ihren Core-Modulen
#    geschrieben werden — jede Mutation dort erzeugt garantiert ein Log-Event.
# 2. Jeder in Modulen verwendete reason-Code muss in der Reason-Registry
#    (hrp_core/shared/reasons.lua) registriert sein.
#
# Exit != 0 bei Verstößen -> läuft in der CI.
set -euo pipefail
cd "$(dirname "$0")/.."

RES="gameserver/resources"
fail=0

# --- 1. Schreibzugriffe auf geschützte Tabellen ------------------------------

check_table() {
    local table="$1"; shift
    local allowed=("$@")
    local hits
    hits=$(grep -rln --include='*.lua' -E "(UPDATE|INSERT INTO|DELETE FROM)[[:space:]]+${table}\b" "$RES" || true)
    for file in $hits; do
        local ok=0
        for allow in "${allowed[@]}"; do
            [[ "$file" == *"$allow" ]] && ok=1
        done
        if [ "$ok" -eq 0 ]; then
            echo "VERSTOSS: $file schreibt auf geschützte Tabelle '$table'"
            fail=1
        fi
    done
}

echo "== 1. Geschützte Tabellen =="
check_table "character_money" \
    "hrp_core/server/money.lua" \
    "hrp_characters/server/main.lua"        # nur INSERT der 0-Zeile bei Erstellung
check_table "company_funds" \
    "hrp_core/server/money.lua" \
    "hrp_companies/server/main.lua"         # nur INSERT der 0-Zeile bei Gründung
check_table "item_instances" "hrp_inventory/server/main.lua"
check_table "item_locations" "hrp_inventory/server/main.lua"
check_table "state_treasury" "hrp_core/server/money.lua"

# Die Erstellungs-INSERTs dürfen keinen Startsaldo setzen (Geld nur via API):
if grep -rn --include='*.lua' -E "INSERT INTO (character_money|company_funds)[^)]*balance|INSERT INTO character_money \(character_id, ?(cash|bank)" "$RES" | grep -v 'VALUES (?)' ; then
    echo "VERSTOSS: Erstellungs-INSERT setzt einen Startsaldo (Geld darf nur über die Geld-API entstehen)"
    fail=1
fi
echo "OK"

# --- 2. Reason-Codes gegen die Registry --------------------------------------

echo "== 2. Reason-Code-Registry =="
registered=$(grep -oE "\['[a-z_]+\.[a-z_]+'\]" "$RES/[hrp]/hrp_core/shared/reasons.lua" | tr -d "[]'")

# Zeilen mit Geld-/Item-API-Aufrufen: dort verwendete 'a.b'-Literale extrahieren
used=$(grep -rh --include='*.lua' -E "(MoneyCreate|MoneyDestroy|MoneyTransfer|MoneyCompanyTransfer|Money\.Create|Money\.Destroy|Money\.Transfer|Inv:Create|Inventory\.Create|Inv:Destroy|Inventory\.Destroy|Inv:Consume)" "$RES" \
    | grep -oE "'[a-z_]+\.[a-z_]+'" | tr -d "'" | sort -u || true)

for code in $used; do
    if ! echo "$registered" | grep -qx "$code"; then
        echo "VERSTOSS: reason-Code '$code' wird verwendet, ist aber nicht in reasons.lua registriert"
        fail=1
    fi
done
echo "OK ($(echo "$used" | grep -c . || true) Codes geprüft)"

if [ "$fail" -ne 0 ]; then
    echo ""
    echo "Audit FEHLGESCHLAGEN — Mutationen an den Core-APIs vorbei sind ein Review-Blocker."
    exit 1
fi
echo ""
echo "Log-Vollständigkeits-Audit bestanden."
