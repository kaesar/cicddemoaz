#!/usr/bin/env bash
# Carga datos de ejemplo en XDB (/abc savePoint). Uso: ./seed-xdb.sh [TOKEN]
set -euo pipefail
XDB_BASE="${XDB_BASE:-http://localhost:9990}"
TOKEN="${1:-${E2E_TOKEN:-}}"
AUTH=()
if [ -n "$TOKEN" ]; then AUTH=(-H "Authorization: Bearer $TOKEN"); fi

seed_one() {
  local id="$1" payload="$2"
  curl -sf -X POST "$XDB_BASE/abc" -H 'Content-Type: application/json' "${AUTH[@]}" \
    -d "{\"what\":\"savePoint\",\"from\":\"xyany\",\"some\":\"PRODUCTS.SHEET\",\"id\":\"$id\",\"payload\":$payload}" | head -c 200; echo
}

echo "Seeding $XDB_BASE ..."
seed_one "p1" '{"name":"Portátil 14","price":899,"stock":12}'
seed_one "p2" '{"name":"Teclado ES","price":49,"stock":100}'
seed_one "p3" '{"name":"Monitor 27","price":229,"stock":30}'
echo "Listado verificación:"
curl -sf -X POST "$XDB_BASE/abc" -H 'Content-Type: application/json' "${AUTH[@]}" \
  -d '{"what":"find","from":"xyany","some":"PRODUCTS.SHEET","size":"50"}' | head -c 1000; echo
echo OK
