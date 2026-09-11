#!/usr/bin/env bash
# Carga datos de ejemplo en XDB (/abc insert). Uso: ./seed-xdb.sh [TOKEN]
# Sin TOKEN llama sin Authorization (vale si XDB está en modo decode-only/dev).
# Idempotente: omite filas ya existentes (XDB responde "Already exists").
set -euo pipefail
XDB_BASE="${XDB_BASE:-http://localhost:9990}"
TOKEN="${1:-${E2E_TOKEN:-}}"
FORCE="${FORCE:-0}"

# curl con Bearer opcional. Sin arrays: compatible con bash 3.2 (macOS) + `set -u`,
# donde "${AUTH[@]}" con array vacío aborta con "unbound variable".
# Imprime el body y devuelve 0 solo si HTTP 2xx.
curl_api() {
  local out code
  if [ -n "$TOKEN" ]; then
    out=$(curl -s -w '\n%{http_code}' -H "Authorization: Bearer $TOKEN" "$@")
  else
    out=$(curl -s -w '\n%{http_code}' "$@")
  fi
  code=$(printf '%s' "$out" | tail -1)
  printf '%s' "$out" | sed '$d' # body sin la última línea (código HTTP); portable macOS/Linux
  [ "$code" -ge 200 ] && [ "$code" -lt 300 ]
}

find_total() {
  local resp
  resp=$(curl_api -X POST "$XDB_BASE/abc" -H 'Content-Type: application/json' \
    -d '{"what":"find","from":"xyany","some":"PRODUCTS.SHEET","size":"1"}') \
    || { echo "FAIL find en $XDB_BASE/abc (¿XDB caído o 401? Pasa un token: ./seed-xdb.sh <TOKEN>)" >&2; return 1; }
  printf '%s' "$resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("total") or 0)'
}

# Insert real de XDB: what=insert + puts como STRING json (columnas any01, any02, ...).
seed_one() {
  local name="$1" price="$2" stock="$3" body resp
  body=$(python3 -c 'import json,sys; print(json.dumps({"what":"insert","from":"xyany","some":"PRODUCTS.SHEET","puts":json.dumps({"any01":sys.argv[1],"any02":sys.argv[2],"any03":sys.argv[3]})}))' "$name" "$price" "$stock")
  if resp=$(curl_api -X POST "$XDB_BASE/abc" -H 'Content-Type: application/json' -d "$body"); then
    printf '%s' "$resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("seed:", d.get("ok"), (d.get("data") or [{}])[0].get("id"))'
  elif printf '%s' "$resp" | grep -q 'Already exists'; then
    echo "seed: $name ya existe, omito"
  else
    echo "FAIL insert $name: $resp" >&2
    return 1
  fi
}

echo "Seeding $XDB_BASE ..."
total=$(find_total) || exit 1
if [ "$total" -gt 0 ] && [ "$FORCE" != "1" ]; then
  echo "PRODUCTS.SHEET ya tiene datos, omito inserts (FORCE=1 para forzar)."
else
  seed_one "Portátil 14" "899" "12"
  seed_one "Teclado ES" "49" "100"
  seed_one "Monitor 27" "229" "30"
fi
echo "Listado verificación:"
resp=$(curl_api -X POST "$XDB_BASE/abc" -H 'Content-Type: application/json' \
  -d '{"what":"find","from":"xyany","some":"PRODUCTS.SHEET","size":"50"}') \
  || { echo "FAIL find en $XDB_BASE/abc" >&2; exit 1; }
printf '%.1000s\n' "$resp"
echo OK
