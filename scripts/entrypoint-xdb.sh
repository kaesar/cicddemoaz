#!/bin/sh
# Entrypoint de la imagen XDB para Azure: xdb solo lee onmind.ini
# (ignora variables de entorno), así se genera el fichero desde env al arrancar.

set -eu
for d in /opt/onmind /root/onmind /app /opt/onmind/run; do
  mkdir -p "$d"
done
TMP_INI=$(mktemp)
{
echo "# Generado por entrypoint-xdb.sh desde env"
echo "app.mode = production"
echo "app.local = /opt/onmind/run/"
echo "app.base = /app"
echo "app.language = en"
echo "app.logger = -"
echo "app.modality = 5"
echo "app.deploy = 0"
echo "app.ui = +"
echo "dai.port = 9990"
echo "dai.cors = *"
echo ""
echo "db.query_limit = 1200"
echo "db.export = -"
echo "file.enabled = -"
echo "mcp.enabled = -"
echo "grpc.enabled = -"
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
} > "$TMP_INI"
for f in /opt/onmind/onmind.ini /root/onmind/onmind.ini /app/onmind.ini /opt/onmind/run/onmind.ini; do
  cp "$TMP_INI" "$f"
done
rm -f "$TMP_INI"
mkdir -p /opt/onmind/run/xy /app/xy
# Eco de prueba (sin secretos): visible en Log Analytics aunque el arranque falle después.
echo "[entrypoint-xdb] onmind.ini en /opt/onmind /root/onmind /app /opt/onmind/run (auth.type=${XDB_AUTH_TYPE:-ENTRAID} kv.store=${XDB_KV_STORE:-mvstore})"
exec java ${JAVA_OPTS:-} -jar /opt/onmind/run/onmind-xdb.jar onmindxdb
