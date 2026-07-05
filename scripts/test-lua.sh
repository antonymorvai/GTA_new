#!/usr/bin/env bash
# Führt die Lua-Unit-Tests (pure Shared-Funktionen) mit Standard-Lua aus
# und prüft die Syntax aller Ressourcen-Dateien.
# Voraussetzung: lua5.4 + luac5.4 (apt install lua5.4)
set -euo pipefail
cd "$(dirname "$0")/.."

LUA="${LUA:-lua5.4}"
LUAC="${LUAC:-luac5.4}"

echo "== Syntax-Check aller Lua-Dateien =="
fail=0
while IFS= read -r file; do
    if ! "$LUAC" -p "$file" 2>/dev/null; then
        echo "SYNTAXFEHLER: $file"
        "$LUAC" -p "$file" || true
        fail=1
    fi
done < <(find gameserver/resources -name '*.lua')
[ "$fail" -eq 0 ] && echo "OK"

echo "== Unit-Tests (pure Funktionen) =="
for test in tests/lua/*_test.lua; do
    echo "-- $test"
    "$LUA" "$test"
done
