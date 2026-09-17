#!/usr/bin/env bash
# Rota la JWK RS256 de XID: genera clave, la guarda en Key Vault, reinicia la
# revisión para que la tome (las refs son versionless pero la revisión en curso
# conserva el valor viejo) y verifica el endpoint JWKS.
# Sin esto, XID sirve el placeholder (JWKS 500) y no puede firmar tokens.
# Uso: ./scripts/rotate-xid-keys.sh [VAULT] [RG] [APP]
set -euo pipefail
KV="${1:-${KV_NAME:-onmind-app-kv}}"
RG="${2:-${RG_NAME:-rg-cicddemoaz}}"
APP="${3:-${XID_APP:-onmind-app-xid}}"

command -v node >/dev/null || { echo "FAIL: se requiere node para generar la JWK" >&2; exit 1; }
command -v az >/dev/null || { echo "FAIL: se requiere az CLI (az login)" >&2; exit 1; }

TMP=$(mktemp /tmp/xid-rsa-jwk.XXXXXX.json)
trap 'rm -f "$TMP"' EXIT  # la privada nunca queda en disco

node -e "const fs=require('fs');const{generateKeyPairSync}=require('crypto');const{privateKey}=generateKeyPairSync('rsa',{modulusLength:2048});const jwk=privateKey.export({format:'jwk'});jwk.kid='xid-1';jwk.alg='RS256';jwk.use='sig';fs.writeFileSync(process.argv[1],JSON.stringify(jwk));" "$TMP"

az keyvault secret set --vault-name "$KV" -n xid-rsa-jwk --file "$TMP" -o none
echo "secreto xid-rsa-jwk actualizado en $KV"

REV=$(az containerapp revision list -n "$APP" -g "$RG" --query '[0].name' -o tsv)
az containerapp revision restart -n "$APP" -g "$RG" --revision "$REV" -o none
echo "revisión $REV reiniciada, esperando 20s..."
sleep 20

XID_FQDN=$(az containerapp show -n "$APP" -g "$RG" --query properties.configuration.ingress.fqdn -o tsv)

# Los refs Key Vault se resuelven al CREAR la revisión: si el restart no bastó,
# el JWKS seguirá con el valor viejo y hará falta una revisión nueva (re-lanzar pipeline).
if curl -sfL "https://$XID_FQDN/common/discovery/v2.0/keys" | grep -q '"keys"'; then
  curl -sL "https://$XID_FQDN/common/discovery/v2.0/keys" | head -c 60; echo
  echo OK
else
  echo "FAIL: JWKS aún sin keys tras restart — relanza el pipeline para crear una revisión nueva" >&2
  exit 1
fi
