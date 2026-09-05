# Ejercicio Integración: WebApp + XID (Entra facade) + XDB (Cosmos DB) en Azure

Escenario completo de integración pensado para Azure:

- **WebApp dummy** (React + `@azure/msal-browser`) autentica usuarios contra **OnMind-XID** (`../xid` o `https://github.com/kaesar/onmind-xid`) que simula **Microsoft Entra ID** (facade OIDC).
- Tras login, la WebApp obtiene listado desde **OnMind-XDB** (`../xdb` o `https://github.com/kaesar/onmind-xdb`, endpoints `/abc` y `/files`).
- XDB persiste en **Azure Cosmos DB (SQL API)** vía `kv.store=cosmos` + `CosmosPlug`.
- Infra 100% **Terraform**: RG, Cosmos DB, ACR, Container Apps Environment + 2 Container Apps (XID/XDB), Static Web Apps (opcional), Key Vault + Managed Identity.
- CI/CD con **Azure DevOps Pipelines** multi-stage: Build → Test → Deploy (ACR + Terraform) → Smoke E2E.

```
┌─────────────────────┐     OIDC / Entra facade      ┌──────────────────────┐
│  WebApp Dummy       │ ───────────────────────────► │  OnMind-XID (IdP)    │
│  (React + MSAL.js)  │ ◄── Access / Id Token        │  (Bun + Hono)        │
└─────────┬───────────┘                              └──────────────────────┘
          │ Bearer Token + POST /abc
          ▼
┌─────────────────────┐     Persistencia KV          ┌──────────────────────┐
│  OnMind-XDB         │ ───────────────────────────► │  Azure Cosmos DB     │
│  (Kotlin + http4k)  │                              │  SQL API             │
│  /abc  ·  /files    │                              └──────────────────────┘
└─────────────────────┘
```

## Estructura

```
./  (raíz del proyecto)
├── README.md
├── docker-compose.yml          # referencia local: XID :8787 + XDB :9990 + WebApp :3000
├── .env.example
├── config/
│   ├── onmind.ini.example      # XDB: OIDCPlug/CognitoPlug + CosmosPlug
│   └── xid.env.example         # XID: facade Entra + CORS + OTP allowlist
├── docs/
│   ├── arquitectura.md
│   ├── flujo-auth.md
│   └── checklist.md
├── app/                        # React + Vite + @azure/msal-browser
├── iac/
│   └── terraform/              # Único IaC (sin Ansible)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── cosmos.tf
│       ├── container-apps.tf
│       ├── acr.tf
│       ├── keyvault.tf
│       └── swa.tf
├── pipe/
│   ├── azure-pipelines.yml
│   └── blueprint/
└── scripts/
    ├── seed-xdb.sh
    └── e2e-test.sh
```

## Quickstart local

Requisito: tener `../xid` y `../xdb` clonados (o usar imágenes Docker).

```bash
# 1. XID (IdP facade Entra) - puerto 8787
cd ../../xid
echo "alice@example.com" > userbase.txt
bun install && bun run dev
# verificar discovery:
curl http://localhost:8787/common/v2.0/.well-known/openid-configuration | jq

# 2. XDB (API) - puerto 9990, con auth OIDC hacia XID
cd ../../xdb
cp ./config/onmind.ini.example ./onmind.ini
./gradlew run
curl -X POST http://localhost:9990/abc -H 'Content-Type: application/json' \
  -d '{"what":"find","from":"xyany","some":"PRODUCTS.SHEET","size":"5"}'

# 3. WebApp - puerto 3000
cd ./app
cp .env.example .env
npm install && npm run dev
# abrir http://localhost:3000 → Login → Listar datos
```

O con Docker Compose (referencia):

```bash
docker compose up --build
```

## Flujo principal

1. Usuario abre WebApp → `loginRedirect` a XID `/{tenant}/oauth2/v2.0/authorize` con PKCE.
2. XID: formulario email → OTP (allowlist `userbase.txt`) → emite `authorization_code`.
3. WebApp intercambia `code` en `/token` → Access + Id Token (RS256).
4. WebApp llama `POST /abc` con `Authorization: Bearer <access_token>`.
5. XDB valida token (OIDCPlug/CognitoPlug: JWKS, `iss/aud/exp`, `sub/oid/tid`) → consulta KV (H2 local / Cosmos en Azure) → devuelve listado.
6. WebApp renderiza tabla.

Detalle en `docs/flujo-auth.md`. Variables/secrets en `docs/arquitectura.md` y `config/`.

## Despliegue Azure

```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars  # rellenar tenant, subscription, secrets
az login
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Pipeline: ver `pipe/azure-pipelines.yml`. Requiere Service Connection `azure-rm-sc`, ACR, Key Vault y variable groups.

## Quick start en Azure

> El pipeline hace checkout automático de [`onmind-xid`](https://github.com/kaesar/onmind-xid)
> y [`onmind-xdb`](https://github.com/kaesar/onmind-xdb) vía `resources: repositories:`
> (service connection GitHub `github-sc`). No necesitas clonar esos repos en local ni en el agente.

### 0. Prerrequisitos

- `az` CLI, Terraform >= 1.6 y permisos de Contributor en la subscription.
- En Azure DevOps: service connections `azure-rm-sc` (Azure ARM) y `github-sc`
  (GitHub, PAT con lectura a los repos xid/xdb), más el variable group `ejercicio-xid-xdb-vars`.

### 1. Login, subscription y providers

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ContainerRegistry --wait
az provider register -n Microsoft.DocumentDB --wait
az provider register -n Microsoft.KeyVault --wait
az provider register -n Microsoft.Web --wait
az provider register -n Microsoft.OperationalInsights --wait
```

### 2. Storage para el tfstate (lo exige el pipeline)

```bash
az group create -n rg-tfstate -l westeurope
az storage account create -n <sttfstatexxx> -g rg-tfstate --sku Standard_LRS
az storage container create -n tfstate --account-name <sttfstatexxx>
```

### 3. Variable group `ejercicio-xid-xdb-vars` (Pipelines → Library)

| Variable | Valor inicial |
|---|---|
| `TFSTATE_RG` / `TFSTATE_SA` | `rg-tfstate` / `<sttfstatexxx>` |
| `ACR_NAME` / `ACR_LOGIN_SERVER` | se rellenan tras el bootstrap (paso 4) |
| `PREFIX` / `LOCATION` | `onmind-ej` / `westeurope` |
| `XID_BASE` / `XDB_BASE` / `E2E_TOKEN` / `XID_TENANT` | se rellenan tras el primer deploy |

### 4. Bootstrap de infra (una vez, en local, con imágenes placeholder)

```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars  # rellenar subscription_id, prefix, location
terraform init -backend=false
terraform validate
terraform apply \
  -var 'xid_image=mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' \
  -var 'xdb_image=mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
# anotar outputs: acr_login_server, xid_url, xdb_url, key_vault_uri
```

### 5. Completar variables y lanzar el pipeline

1. En el variable group: `ACR_NAME=<nombre>` y `ACR_LOGIN_SERVER=<salida acr_login_server>`.
2. Crear el pipeline desde `pipe/azure-pipelines.yml` y ejecutarlo (Build → Test → Deploy → Smoke).
   El stage Deploy construye las imágenes de `xid`, `xdb` (repos externos) y `app` y las sube a ACR.
3. Guardar el secreto RSA de XID en Key Vault:
   ```bash
   az keyvault secret set --vault-name <kv-del-output> -n xid-rsa-jwk --file ./xid-rsa-jwk.json
   ```
4. Re-ejecutar el stage Deploy para que las Container Apps tomen los secretos.

### 6. Smoke test manual

```bash
export XID_BASE="https://<xid_url>" XDB_BASE="https://<xdb_url>" E2E_TOKEN="<access_token-otp>"
./scripts/e2e-test.sh
curl -s "$XID_BASE/common/v2.0/.well-known/openid-configuration" | head -c 300; echo
```

## Checklist entregables

Ver `docs/checklist.md`.
