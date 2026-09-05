# Checklist de entregables

- [ ] Diagrama de arquitectura (Mermaid en `docs/arquitectura.md` + ASCII en README)
- [ ] Secuencia completa OIDC facade Entra (`docs/flujo-auth.md` + `scripts/e2e-test.sh`)
- [ ] WebApp dummy funcional (`app/`): login MSAL + botón Listar → `POST /abc` con Bearer
- [ ] XDB configurado con Cosmos DB y protegido por token XID (`config/onmind.ini.example`, validación iss/aud/exp)
- [ ] Pipeline Azure DevOps (`pipe/azure-pipelines.yml`): build + test + deploy + smoke
- [ ] Terraform que aprovisiona todo (`iac/terraform/*.tf`): RG, Cosmos, ACR, CAE+2 CApps, SWA opcional, Key Vault, MI+roles
- [ ] Documentación de env/secrets (`docs/arquitectura.md` § Variables, `config/`, `app/.env.example`)
- [ ] Script E2E (`scripts/e2e-test.sh` curl; `scripts/seed-xdb.sh` carga inicial)
- [ ] `docker-compose.yml` local (XID :8787 + XDB :9990 + WebApp :3000 + Cosmos emulator opcional)
- [ ] CORS configurado (`XID_CORS_ORIGINS`, headers XDB)
- [ ] Secrets solo en Key Vault / variableGroups (verificado con `grep -r` sin secretos en repo)

## Criterios de aceptación

1. `docker compose up` → login OTP mock → Listar devuelve ≥1 fila seed.
2. `terraform validate && terraform plan` sin errores.
3. `az pipelines run` en verde: build/test/deploy/smoke.
4. Reinicio XDB no pierde datos (persisten en Cosmos).
5. `401` sin token; `200` con token válido de XID.
