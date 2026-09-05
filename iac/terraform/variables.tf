variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "prefix" {
  description = "Prefijo de nombres (ej. onmind-ej)"
  type        = string
  default     = "onmind-ej"
}

variable "location" {
  description = "Región Azure"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
  default     = "rg-onmind-ejercicio"
}

variable "tags" {
  type    = map(string)
  default = { proyecto = "ejercicio-integracion", iac = "terraform" }
}

# --- XID ---
variable "xid_image" {
  description = "Imagen XID en ACR (ej. <acr>.azurecr.io/xid:latest)"
  type        = string
}
variable "xid_tenant" {
  description = "Tenant facade Entra (common o guid)"
  type        = string
  default     = "common"
}
variable "xid_client_id" {
  description = "Client ID esperado (aud)"
  type        = string
  default     = "my-webapp"
}
variable "xid_cors_origins" {
  description = "Orígenes CORS permitidos"
  type        = string
  default     = "http://localhost:3000"
}

# --- XDB ---
variable "xdb_image" {
  description = "Imagen XDB en ACR"
  type        = string
}
variable "xdb_auth_enforced" {
  description = "Si true, XDB exige provider=oidc (bloquea anon en Azure)"
  type        = bool
  default     = true
}
variable "xdb_oidc_audience" {
  type    = string
  default = "api://my-webapp"
}

# --- Cosmos ---
variable "cosmos_db_name" {
  type    = string
  default = "onmind"
}
variable "cosmos_container_name" {
  type    = string
  default = "kv"
}
variable "cosmos_throughput" {
  type    = number
  default = 400
}

# --- SWA ---
variable "enable_swa" {
  type    = bool
  default = true
}
variable "swa_repository_url" {
  description = "Repo GitHub de la webapp para SWA (opcional si deploy por pipeline)"
  type        = string
  default     = ""
}
variable "swa_branch" {
  type    = string
  default = "main"
}
