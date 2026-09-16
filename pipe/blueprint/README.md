# Blueprint de pipeline: qué espera cada stage y qué variables configurar.

> Importar en Azure DevOps: Pipelines → New → Existing YAML → pipe/azure-pipelines.yml

````yaml
serviceConnection: azure-rm-sc    # ARM service connection (SP con Contributor + rol tfstate)
variableGroup: cicddemoaz         # variables:
#   ACR_NAME=onmindejacr
#   ACR_LOGIN_SERVER=onmindejacr.azurecr.io
#   TFSTATE_RG=rg-tfstate  TFSTATE_SA=sttfstatexxx
#   PREFIX=onmind-ej  LOCATION=eastus
#   XID_BASE=https://<xid>.eastus.azurecontainerapps.io
#   XDB_BASE=https://<xdb>.eastus.azurecontainerapps.io
#   E2E_TOKEN=<access_token OTP válido> (o service principal test user)
#   XID_TENANT=common

repos:
  xid: submodule https://github.com/kaesar/onmind-xid
  xdb: submodule https://github.com/kaesar/onmind-xdb

stages:
  Build: [xid bun build, xdb shadowJar, app bun build → artifacts]
  Test: [bun test, gradle test, vitest run, integración OTP mock]
  Deploy: [docker push ACR ×3, terraform init/plan/apply]
  Smoke: [scripts/e2e-test.sh con XID_BASE/XDB_BASE/E2E_TOKEN]
```
