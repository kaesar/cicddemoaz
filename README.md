# Integration Exercise: WebApp + XID (Entra facade) + XDB (Cosmos DB) on Azure

Full integration scenario designed for Azure:

- **Dummy WebApp** (React + manual PKCE with `fetch`, no MSAL) authenticates users against [**OnMind-XID**](https://github.com/kaesar/onmind-xid), which simulates **Microsoft Entra ID** (OIDC facade).
- After login, the WebApp fetches a data listing from [**OnMind-XDB**](https://github.com/kaesar/onmind-xdb) (`/abc` and `/files` endpoints).
- XDB persists to **Azure Cosmos DB (SQL API)** via `kv.store=cosmosdb` (`KVStoreFactory` → `CosmosPlug`).
- 100% **Terraform** infra: RG, Cosmos DB, ACR, Container Apps Environment + 2 Container Apps (XID/XDB), Static Web Apps (optional), Key Vault + Managed Identity.
- CI/CD with multi-stage **Azure DevOps Pipelines**: Build → Test → Deploy (ACR + Terraform) → Smoke E2E.

```
┌─────────────────────┐     OIDC / Entra facade      ┌──────────────────────┐
│  Dummy WebApp       │ ───────────────────────────► │  OnMind-XID (IdP)    │
│(React + manual PKCE)│ ◄── Access / Id Token        │  (Bun + Hono)        │
└─────────┬───────────┘                              └──────────────────────┘
          │ Bearer Token + POST /abc
          ▼
┌─────────────────────┐     KV persistence           ┌──────────────────────┐
│  OnMind-XDB         │ ───────────────────────────► │  Azure Cosmos DB     │
│  (Kotlin + http4k)  │                              │  SQL API             │
│  /abc  ·  /files    │                              └──────────────────────┘
└─────────────────────┘
```

## Structure

```
./  (project root)
├── README.md
├── docker-compose.yml          # local reference: XID :8787 + XDB :9990 + WebApp :3000
├── .env.example
├── config/
│   ├── onmind.ini.example      # XDB: auth.type=ENTRAID + kv.store (Properties, no sections)
│   └── xid.env.example         # XID: Entra facade + CORS + OTP allowlist
├── docs/
│   ├── arquitectura.md
│   ├── flujo-auth.md
│   └── checklist.md
├── app/                        # React + Vite + manual PKCE (fetch, no MSAL)
├── iac/
│   └── terraform/              # Single IaC (no Ansible)
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

## Local quickstart

> **Requirement**: have [**OnMind-XID**](https://github.com/kaesar/onmind-xid) and [**OnMind-XDB**](https://github.com/kaesar/onmind-xdb) cloned.

```bash
# 1. OnMind-XID (Entra facade IdP) - port 8787
git clone --depth 1 https://github.com/kaesar/onmind-xid.git xid
cd xid
echo "alice@example.com" > xusers.txt
# Optional: real bcrypt password alongside OTP: cd xid && bun run cli user password alice@example.com
bun install
# Environment variables
XID_JWT_SECRET=$(openssl rand -hex 32) XID_CORS_ORIGINS=http://localhost:3000 bun dev &
# check discovery:
curl http://localhost:8787/common/v2.0/.well-known/openid-configuration | jq

# 2. OnMind-XDB (NoSQL - DB-API) - port 9990, with OIDC auth towards XID
cd ..
git clone --depth 1 https://github.com/kaesar/onmind-xdb.git xdb
# XDB only reads onmind.ini (ignores env): single source in ../config/onmind.ini
cp ./config/onmind.ini.example ./config/onmind.ini
ln -sf config/onmind.ini onmind.ini  # Rote looks for ../onmind.ini from xdb/
cd xdb
./gradlew run &
curl http://localhost:9990/health -H 'Content-Type: application/json' | jq

# 3. WebApp - port 3000
cd ./app
cp .env.example .env
bun install
bun dev
```

> Open `http://localhost:3000` in your browser  
> Using `&`, `xid` and `xdb` stay available in the background; you can also skip it and open several terminals for local monitoring
<!--
Or with Docker Compose (reference):

```bash
docker compose up --build
```
-->
## Main flow

1. User opens the WebApp → navigates to XID `/{tenant}/oauth2/v2.0/authorize` with PKCE (S256, WebCrypto).
2. XID: email form → OTP or password (allowlist `xusers.txt`) → issues `authorization_code`.
3. WebApp exchanges `code` at `/token` → Access + Id Token (RS256).
4. WebApp calls `POST /abc` with `Authorization: Bearer <access_token>`.
5. XDB validates the Bearer (`auth.type=ENTRAID`: HS256 with secret or signature-less decoded payload
   in dev; no JWKS calls) → queries KV (local mvstore / Cosmos DB on Azure) → returns the listing.
6. WebApp renders the table.

Details in `docs/flujo-auth.md`. Variables/secrets in `docs/arquitectura.md` and `config/`.

## Azure deployment

```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars  # fill in tenant, subscription, secrets
az login
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Pipeline: see `pipe/azure-pipelines.yml`. Requires Service Connection `azure-rm-sc`, ACR, Key Vault and variable groups.

## Quick start on Azure

> The pipeline auto-checkouts [`onmind-xid`](https://github.com/kaesar/onmind-xid)
> and [`onmind-xdb`](https://github.com/kaesar/onmind-xdb) via `resources: repositories:`
> (GitHub `github-sc` service connection). You don't need to clone those repos locally or on the agent.

### 0. Prerequisites

- `az` CLI, Terraform >= 1.6 and Contributor permissions on the subscription.
- In Azure DevOps: `azure-rm-sc` (Azure ARM) and `github-sc` service connections
  (GitHub, PAT with read access to the xid/xdb repos), plus the `cicddemoaz` variable group.

### 1. Login, subscription and providers

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ContainerRegistry --wait
az provider register -n Microsoft.DocumentDB --wait
az provider register -n Microsoft.KeyVault --wait
az provider register -n Microsoft.Web --wait
az provider register -n Microsoft.OperationalInsights --wait
az provider register -n Microsoft.Storage --wait
```

> `<SUBSCRIPTION_ID>` refers to the subscription ID in the Azure Portal. If you have a trial account, you have a default one and do not need this command.  
> The commands using `az provider register -n` are run at least once for security purposes to enable the resource type in the Azure resource provider. Services: Azure Container Apps, ACR, Cosmos DB, Key Vault, Static Web Apps, Analytics, Storage (required to avoid `SubscriptionNotFound`).

### 2. Storage for tfstate (required by the pipeline)

```bash
az group create -n rg-tfstate -l eastus
az storage account create -n satfstatecicddemoaz -g rg-tfstate --sku Standard_LRS
az storage container create -n tfstate --account-name satfstatecicddemoaz
```

### 3. `cicddemoaz` variable group (Pipelines → Library)

| Variable | Initial value |
|---|---|
| `TFSTATE_RG` / `TFSTATE_SA` | `rg-tfstate` / `satfstatecicddemoaz` |
| `ACR_NAME` / `ACR_LOGIN_SERVER` | filled in after bootstrap (step 4) |
| `PREFIX` / `LOCATION` | `onmind-ej` / `eastus` |
| `XID_BASE` / `XDB_BASE` / `E2E_TOKEN` / `XID_TENANT` | filled in after the first deploy |

> These variables are added from **Azure Pipelines**

### 4. Infra bootstrap (once, locally, with placeholder images)

```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init -backend=false
terraform validate
terraform plan -out=tfplan \
  -var 'xid_image=mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' \
  -var 'xdb_image=mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
terraform apply tfplan
```

> For `terraform.tfvars` fill in subscription_id, prefix, location.  
> When finish `apply` note the outputs: `acr_login_server`, `xid_url`, `xdb_url`, `key_vault_uri`

### 5. Fill in variables and run the pipeline

1. In the variable group: `ACR_NAME=<name>` and `ACR_LOGIN_SERVER=<acr_login_server output>`.
2. Create the pipeline from `pipe/azure-pipelines.yml` and run it (Build → Test → Deploy → Smoke).
   The Deploy stage builds the `xid`, `xdb` (external repos) and `app` images and pushes them to ACR.
3. Store the XID RSA secret in Key Vault:
   ```bash
   az keyvault secret set --vault-name <kv-from-output> -n xid-rsa-jwk --file ./xid-rsa-jwk.json
   ```
4. Re-run the Deploy stage so the Container Apps pick up the secrets.

> **XID users (`xusers.txt`) on Azure:** the production image expects `/data/xusers.txt`
> (`XID_USERS_TXT`, see xid `Dockerfile`) and only ships the `.example` files. Provide it
> via an Azure Files mount at `/data` (plus SMTP env `XID_SMTP_*` and `XID_ENV=production`,
> otherwise OTP has no transport), or bake it at build time. Manage entries with the xid
> CLI (`bun run cli user add|password|list <email>`); password hashes (bcrypt) live in the
> file itself, no Key Vault secret needed for them.

### 6. Manual smoke test

```bash
export XID_BASE="https://<xid_url>" XDB_BASE="https://<xdb_url>" E2E_TOKEN="<otp-access_token>"
./scripts/e2e-test.sh
curl -s "$XID_BASE/common/v2.0/.well-known/openid-configuration" | head -c 300; echo
```
