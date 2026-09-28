#!/usr/bin/env bash
# Smoke E2E: discovery XID + JWKS + /abc con Bearer + rechazo anónimo.
# Uso: XID_BASE=.. XDB_BASE=.. E2E_TOKEN=.. ./e2e-test.sh
# Sin E2E_TOKEN corre en modo parcial (sin userinfo ni /abc autorizado)
set -euo pipefail
XID_BASE="${XID_BASE:-http://localhost:8787}"
XDB_BASE="${XDB_BASE:-http://localhost:9990}"
TENANT="${XID_TENANT:-common}"
TOKEN="${E2E_TOKEN:-}"

# Normaliza esquema (el grupo suele guardar solo el FQDN).
case "$XID_BASE" in http://*|https://*) ;; *) XID_BASE="https://$XID_BASE";; esac
case "$XDB_BASE" in http://*|https://*) ;; *) XDB_BASE="https://$XDB_BASE";; esac

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

echo "== E2E $XID_BASE / $XDB_BASE =="

DISC="$(curl -sf "$XID_BASE/$TENANT/v2.0/.well-known/openid-configuration")" || fail "discovery $TENANT"
echo "$DISC" | grep -q token_endpoint || fail "discovery sin token_endpoint"
pass "discovery OIDC"

JWKS_URL="$(echo "$DISC" | python3 -c 'import json,sys; print(json.load(sys.stdin)["jwks_uri"])')"
# -L: XID tras el ingress emite URLs http (deriva del Host interno) y el ingress responde 301 hacia https.
curl -sfL "$JWKS_URL" | grep -q '"keys"' || fail "jwks sin keys (¿XID_RSA_PRIVATE_JWK placeholder en Key Vault?)"
pass "jwks"

if [ -z "$TOKEN" ]; then
  echo "SMOKE PARCIAL (sin E2E_TOKEN): discovery + JWKS OK; userinfo y /abc autorizado omitidos"
  echo "Para el E2E completo: login OTP contra $XID_BASE y exporta E2E_TOKEN=<access_token>"
else
  # Se guarda body y HTTP por separado diagnosticando: 404=ruta mal, 401=tokeninválido/caducado.
  U_CODE=$(curl -s -o /tmp/userinfo.json -w '%{http_code}' \
    "$XID_BASE/$TENANT/openid/userinfo" -H "Authorization: Bearer $TOKEN")
  if [ "$U_CODE" != 200 ] || ! grep -q sub /tmp/userinfo.json; then
    fail "userinfo HTTP=$U_CODE (404=ruta, 401=token inválido o caducado)"
  fi
  pass "userinfo"

  A_CODE=$(curl -s -o /tmp/abc.json -w '%{http_code}' -X POST "$XDB_BASE/abc" \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
    -d '{"what":"find","from":"xyany","some":"PRODUCTS.SHEET","size":"5"}')
  if [ "$A_CODE" != 200 ]; then
    fail "/abc con token HTTP=$A_CODE (401=token inválido o caducado)"
  fi
  RESP=$(cat /tmp/abc.json)
  pass "/abc autorizado: $(echo "$RESP" | head -c 120)"
fi

if curl -sf -X POST "$XDB_BASE/abc" -H 'Content-Type: application/json' \
  -d '{"what":"find","from":"xyany","some":"PRODUCTS.SHEET","size":"1"}' >/dev/null 2>&1; then
  echo "WARN: /abc permite anónimo (esperado solo en local con provider=none)"
else
  pass "/abc rechaza anónimo (401)"
fi

if [ -n "$TOKEN" ]; then echo "E2E OK"; else echo "SMOKE PARCIAL OK"; fi
