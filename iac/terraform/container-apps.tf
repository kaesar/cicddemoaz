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
        name  = "XID_TENANT"
        value = var.xid_tenant
      }
      env {
        name  = "XID_CORS_ORIGINS"
        value = var.xid_cors_origins
      }
      env {
        name        = "XID_JWKS_RSA_PRIVATE_JSON"
        secret_name = "xid-rsa-jwk"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 8787
        path      = "/health"
      }
    }
    min_replicas = 1
    max_replicas = 3
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

      # OIDC hacia XID (issuer = FQDN del Container App xid + tenant)
      env {
        name  = "XDB_AUTH_PROVIDER"
        value = var.xdb_auth_enforced ? "oidc" : "oidc"
      }
      env {
        name  = "XDB_OIDC_ISSUER"
        value = "https://${azurerm_container_app.xid.ingress[0].fqdn}/${var.xid_tenant}/v2.0"
      }
      env {
        name  = "XDB_OIDC_AUDIENCE"
        value = var.xdb_oidc_audience
      }
      env {
        name  = "XDB_OIDC_JWKS_URL"
        value = "https://${azurerm_container_app.xid.ingress[0].fqdn}/${var.xid_tenant}/discovery/v2.0/keys"
      }
      env {
        name  = "KV_STORE"
        value = "cosmos"
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
    min_replicas = 1
    max_replicas = 3
  }

  tags = var.tags
}
