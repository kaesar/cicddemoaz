resource "azurerm_container_app" "xid" {
  name                         = "${var.prefix}-xid"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.xid.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.xid.id
  }

  ingress {
    external_enabled = true
    target_port      = 8787
    transport        = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name                = "xid-rsa-jwk"
    key_vault_secret_id = azurerm_key_vault_secret.xid_rsa_jwk.versionless_id
    identity            = azurerm_user_assigned_identity.xid.id
  }

  template {
    container {
      name   = "xid"
      image  = var.xid_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "PORT"
        value = "8787"
      }
      env {
        name  = "XID_ENV"
        value = var.xid_env # dev: OTP por logs + redirect abierto (ejercicio); production exige SMTP + allowlist
      }
      env {
        name  = "XID_TENANT_ID"
        value = var.xid_tenant
      }
      env {
        name  = "XID_CORS_ORIGINS"
        value = var.xid_cors_origins
      }
      env {
        name  = "XID_USERS_TXT"
        value = "/data/xusers.txt"
      }
      env {
        name  = "XID_CLIENTS_TXT"
        value = "/data/xclients.txt"
      }
      env {
        name        = "XID_RSA_PRIVATE_JWK"
        secret_name = "xid-rsa-jwk"
      }
      volume_mounts {
        name = "xid-data"
        path = "/data"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 8787
        path      = "/health"
      }
    }
    volume {
      name         = "xid-data"
      storage_name = azurerm_container_app_environment_storage.xid_data.name
      storage_type = "AzureFile"
    }
    min_replicas = 0 # scale-to-zero: sin tráfico no consume (ejercicio)
    max_replicas = 1 # 1 réplica: xid/xdb guardan estado en memoria sin afinidad de sesión
  }

  tags = var.tags
}

resource "azurerm_container_app" "xdb" {
  name                         = "${var.prefix}-xdb"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.xdb.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.xdb.id
  }

  ingress {
    external_enabled = true
    target_port      = 9990
    transport        = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name                = "cosmos-key"
    key_vault_secret_id = azurerm_key_vault_secret.cosmos_key.versionless_id
    identity            = azurerm_user_assigned_identity.xdb.id
  }
  secret {
    name                = "cosmos-endpoint"
    key_vault_secret_id = azurerm_key_vault_secret.cosmos_endpoint.versionless_id
    identity            = azurerm_user_assigned_identity.xdb.id
  }

  template {
    container {
      name   = "xdb"
      image  = var.xdb_image
      cpu    = 0.5
      memory = "1Gi"

      # xdb solo lee onmind.ini: scripts/entrypoint-xdb.sh lo genera desde estas
      # env al arrancar. COSMOS_ENDPOINT/KEY llegan por referencia a Key Vault.
      env {
        name  = "XDB_AUTH_TYPE"
        value = "ENTRAID"
      }
      env {
        name  = "XDB_OIDC_URL"
        value = "https://${azurerm_container_app.xid.ingress[0].fqdn}"
      }
      env {
        name  = "XDB_OIDC_CLIENT_ID"
        value = var.xdb_oidc_client_id
      }
      env {
        name  = "XDB_KV_STORE"
        value = "cosmosdb"
      }
      env {
        name        = "COSMOS_ENDPOINT"
        secret_name = "cosmos-endpoint"
      }
      env {
        name        = "COSMOS_KEY"
        secret_name = "cosmos-key"
      }
      env {
        name  = "COSMOS_DATABASE"
        value = var.cosmos_db_name
      }
      env {
        name  = "COSMOS_CONTAINER"
        value = var.cosmos_container_name
      }

      liveness_probe {
        transport = "HTTP"
        port      = 9990
        path      = "/health"
      }
    }
    min_replicas = 0 # scale-to-zero: sin tráfico no consume (ejercicio)
    max_replicas = 1 # 1 réplica: xid/xdb guardan estado en memoria sin afinidad de sesión
  }

  tags = var.tags
}
