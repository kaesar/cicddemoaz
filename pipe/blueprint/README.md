# Blueprint de pipeline: qué espera cada stage y qué variables configurar.

> Importar en Azure DevOps: Pipelines → New → Existing YAML → pipe/azure-pipelines.yml

````yaml
serviceConnection: azure-rm-sc  # ARM service connection (SP con Contributor + rol tfstate)
variableGroup: cicddemoaz       # una variable por fila (Deploy autocrea el ACR: sin ACR_*):
#   TFSTATE_RG=rg-tfstate ................ backend remoto (Deploy + Destroy)
#   TFSTATE_SA=satfstatecicddemoaz ....... backend + cuenta del share Files
#   PREFIX=onmind-app  LOCATION=eastus ... nombres y región (el nombre ACR deriva de PREFIX)
#   FILES_SHARE=xid-data ................. share de xusers/xclients
#   XUSERS_CONTENT ....................... xusers.txt multilínea (mails de prueba)
#   XCLIENTS_CONTENT ..................... xclients.txt multilínea (vacío = omite)
#   XID_BASE / XDB_BASE .................. tras primer deploy (Smoke)
#   E2E_TOKEN ............................ access_token OTP real (Smoke)
#   XID_TENANT=common .................... tenant facade (Smoke)

repos:
  xid: checkout resources.repositories (github-sc) https://github.com/kaesar/onmind-xid
  xdb: checkout resources.repositories (github-sc) https://github.com/kaesar/onmind-xdb

stages:
  Build: [xid bun build, xdb shadowJar, app bun build → artifacts]
  Test: [bun test, gradle test, vitest run, integración OTP mock]
  Deploy: [Files share+upload, docker push ACR ×3, terraform init/plan/apply, frontend a SWA]
  Smoke: [seed-xdb.sh opcional con parameters.seed=true, scripts/e2e-test.sh con XID_BASE/XDB_BASE/E2E_TOKEN]
  Destroy: [solo manual con parameters.destroy=true → terraform destroy -auto-approve]
```
