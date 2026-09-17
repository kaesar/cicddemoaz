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
├── .dockerignore               # aligera el contexto del build xdb
├── docker-compose.yml          # local reference: XID :8787 + XDB :9990 + WebApp :3000
├── .env.example
├── config/
│   ├── onmind.ini.example      # XDB: auth.type=ENTRAID + kv.store (Properties, no sections)
│   └── xid.env.example         # XID: Entra facade + CORS + OTP allowlist
├── docs/
│   ├── arquitectura.md         # runtime + diagrama de infraestructura IaC
│   ├── flujo-auth.md
│   └── checklist.md
├── app/                        # React + Vite + PKCE manual (fetch, sin MSAL)
├── iac/
│   └── terraform/              # Single IaC (no Ansible)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── cosmos.tf
│       ├── container-apps.tf
│       ├── acr.tf
│       ├── keyvault.tf
│       ├── swa.tf
│       └── files.tf            # Environment Storage xid-data (Azure Files)
├── pipe/
│   ├── azure-pipelines.yml
│   └── blueprint/
└── scripts/
    ├── seed-xdb.sh
    ├── e2e-test.sh
    ├── entrypoint-xdb.sh       # genera onmind.ini desde env (xdb ignora env)
    └── Dockerfile.xdb          # build xdb (contexto: raíz del workspace)
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

Terraform creates `role_assignment` resources, which needs the pipeline identity to be **Owner or User Access Administrator** (Contributor is not enough → 403 `roleAssignments/write`). Grant it once (you must run this as Owner):

```bash
SP_OBJECT_ID=$(az ad sp list --display-name azure-rm-sc --query '[0].id' -o tsv)

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

> If `SP_OBJECT_ID` is empty, copy the object id from any AuthorizationFailed error in the pipeline log.

### 2. Storage for tfstate (required by the pipeline)

```bash
az group create -n rg-tfstate -l eastus
az storage account create -n satfstatecicddemoaz -g rg-tfstate --sku Standard_LRS
az storage container create -n tfstate --account-name satfstatecicddemoaz
```

### 3. `cicddemoaz` variable group (Pipelines → Library)

One variable per row. Mark `Secret` ones with 🔒 (masked in logs, can't be read back).

| Variable | Secret | Initial value | Used in |
|---|---|---|---|
| `TFSTATE_RG` | – | `rg-tfstate` | Deploy + Destroy (remote backend) |
| `TFSTATE_SA` | – | `satfstatecicddemoaz` | Deploy (backend + Files share account) |
| `PREFIX` | – | `onmind-app` | Deploy (resource names; ACR name derives from it) |
| `LOCATION` | – | `eastus` | Deploy (region, Cosmos/SWA default to `eastus2`) |
| `FILES_SHARE` | – | `xid-data` | Deploy (share + upload + Terraform) |
| `XUSERS_CONTENT` | (secret) | test emails, one per line (e.g. `alice@example.com`) | Deploy (uploaded to the share) |
| `XCLIENTS_CONTENT` | (secret) | *(empty = skip upload)* | Deploy (uploaded to the share) |
| `XID_BASE` | – | *(after first deploy)* | Smoke (`e2e-test.sh`) |
| `XDB_BASE` | – | *(after first deploy)* | Smoke (`e2e-test.sh`) |
| `E2E_TOKEN` | (secret) | *(after first deploy, real OTP token)* | Smoke (`e2e-test.sh`) |
| `XID_TENANT` | – | `common` | Smoke (`e2e-test.sh`) |

> These variables are added from **Azure Pipelines**

### 4. Infra bootstrap (optional: local preview only)

The pipeline self-bootstraps (targeted ACR apply → push → full apply), so this step
is only for reviewing the plan locally before the first run.

```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars  # fill in prefix, location (subscription optional)
terraform init -backend=false
terraform validate
# Optional full preview with placeholder images (the pipeline applies for real):
terraform plan \
  -var 'xid_image=mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' \
  -var 'xdb_image=mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
```

### 5. Fill in variables and run the pipeline

1. In the variable group set `XUSERS_CONTENT` (e.g. `alice@example.com`) — Deploy uploads it
   before the first apply so xid has users from day one. No ACR variables needed:
   Deploy creates the ACR itself (targeted apply) and reads its URL from outputs.
2. Create the pipeline from `pipe/azure-pipelines.yml` and run it (Build → Test → Deploy → Smoke).
   The Deploy stage builds the `xid`, `xdb` (external repos) and `app` images and pushes them to ACR.
3. Generate and store the XID RSA key (one-time; the Terraform placeholder breaks
   JWKS and token signing until replaced):

```bash
./scripts/rotate-xid-keys.sh [VAULT] [RG] [APP]  # defaults: onmind-app-kv rg-cicddemoaz onmind-app-xid
```

> If `setSecret` returns `ForbiddenByRbac`, your user lacks the role (only the
> pipeline SP has it). Grant it once as Owner, wait ~1 min, retry:

```bash
MY_OID=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee-object-id "$MY_OID" \
  --role "Key Vault Secrets Officer" \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-cicddemoaz/providers/Microsoft.KeyVault/vaults/onmind-app-kv
```

4. Re-run the Deploy stage so the Container Apps pick up the secrets.

> **XID users (`xusers.txt`) on Azure:** the production image expects `/data/xusers.txt`
> (`XID_USERS_TXT`, see xid `Dockerfile`) and only ships the `.example` files. The Deploy
> stage creates the `xid-data` share and uploads `XUSERS_CONTENT`/`XCLIENTS_CONTENT` from the
> variable group, mounted at `/data` (plus SMTP env `XID_SMTP_*` and `XID_ENV=production`,
> otherwise OTP has no transport). Manage entries with the xid
> CLI (`bun run cli user add|password|list <email>`); password hashes (bcrypt) live in the
> file itself, no Key Vault secret needed for them.

### 6. Manual smoke test

Fill the group once (FQDNs are stable across revisions):

```bash
XID_FQDN=$(az containerapp show -n onmind-app-xid -g rg-cicddemoaz --query properties.configuration.ingress.fqdn -o tsv)
XDB_FQDN=$(az containerapp show -n onmind-app-xdb -g rg-cicddemoaz --query properties.configuration.ingress.fqdn -o tsv)
echo "XID_BASE=https://$XID_FQDN XDB_BASE=https://$XDB_FQDN"
```

Without `E2E_TOKEN` the smoke runs partial (discovery + JWKS + anonymous rejection).
For the full E2E, get a real OTP token by pointing the local app at Azure:

```bash
cd app
VITE_XID_AUTHORITY="https://$XID_FQDN/common" VITE_XDB_API_URL="https://$XDB_FQDN" bun dev
```

> copy `access_token` from `sessionStorage` (`xid.session`) to assign `E2E_TOKEN`

```bash
export XID_BASE="https://<xid_url>" XDB_BASE="https://<xdb_url>" E2E_TOKEN="<otp-access_token>"
./scripts/e2e-test.sh
curl -s "$XID_BASE/common/v2.0/.well-known/openid-configuration" | head -c 300; echo
```

### 7. Destroy (manual only)

The pipeline has a `destroy` parameter (default `false`): run the pipeline manually,
check the box, and only the `Destroy` stage runs (`terraform destroy -auto-approve`
against the remote backend). It deletes everything tracked in the tfstate (RG, ACR
with its images, Cosmos with its data) — irreversible. The tfstate blob itself and
the `xid-data` share contents survive unless removed by hand.
