#!/bin/sh
# Entrypoint de la imagen XDB para Azure: xdb (Rote) solo lee onmind.ini
# (ignora variables de entorno), así que se genera el fichero desde env al arrancar.
# COSMOS_ENDPOINT / COSMOS_KEY llegan por referencia a Key Vault (secret refs de
# Container Apps); el pipeline nunca los ve en claro.
set -eu
INI=/opt/onmind/run/onmind.ini
{
  echo "dai.port = 9990"
  echo "dai.cors = *"
  echo ""
  echo "auth.enabled = ${XDB_AUTH_ENABLED:-true}"
  echo "auth.type = ${XDB_AUTH_TYPE:-ENTRAID}"
  echo "auth.oidc.url = ${XDB_OIDC_URL:-http://localhost:8787}"
  echo "auth.oidc.client_id = ${XDB_OIDC_CLIENT_ID:-my-webapp}"
  # JwtValidator solo verifica HS256; los token Entra de XID son RS256, así que
  # el secreto SOLO se escribe si viene definido (sin él: decode-only, solo dev).
  if [ -n "${XDB_JWT_SECRET:-}" ]; then echo "auth.jwt.secret = ${XDB_JWT_SECRET}"; fi
  if [ -n "${XDB_JWT_ISSUER:-}" ]; then echo "auth.jwt.issuer = ${XDB_JWT_ISSUER}"; fi
  echo ""
  echo "kv.store = ${XDB_KV_STORE:-mvstore}"
  echo "kv.mvstore.name = ${XDB_KV_MVSTORE_NAME:-xybox}"
  # endpoint/key solo si vienen definidos; si kv.store=cosmosdb y faltan,
  # xdb falla alto con "kv.cosmosdb.endpoint is required".
  if [ -n "${COSMOS_ENDPOINT:-}" ]; then echo "kv.cosmosdb.endpoint = ${COSMOS_ENDPOINT}"; fi
  if [ -n "${COSMOS_KEY:-}" ]; then echo "kv.cosmosdb.key = ${COSMOS_KEY}"; fi
  echo "kv.cosmosdb.database = ${COSMOS_DATABASE:-onmind}"
  echo "kv.cosmosdb.container = ${COSMOS_CONTAINER:-kvstore}"
} > "$INI"
exec java ${JAVA_OPTS:-} -jar /opt/onmind/run/onmind-xdb.jar onmindxdb
