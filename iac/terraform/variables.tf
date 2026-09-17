variable "subscription_id" {
  description = "Azure subscription ID (vacío = la del contexto az CLI)"
  type        = string
  default     = ""
}

variable "prefix" {
  description = "Prefijo de nombres (ej. onmind-app)"
  type        = string
  default     = "onmind-app"
}

variable "location" {
  description = "Región Azure"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
  default     = "rg-cicddemoaz"
}

variable "tags" {
  type    = map(string)
  default = { proyecto = "cicddemoaz", iac = "terraform" }
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
variable "xid_env" {
  description = "XID_ENV en Azure: dev (OTP por logs, redirect abierto) o production (exige SMTP + allowlist)"
  type        = string
  default     = "dev"
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
variable "xdb_oidc_client_id" {
  description = "client_id público de la app ante XID (debe coincidir entre authorize y token)"
  type        = string
  default     = "my-webapp"
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
variable "cosmos_free_tier" {
  description = "Descuento free tier de por vida (1000 RU/s + 25 GB). Uno por subscription y solo al crear la cuenta. Default false para reservarlo a otro repo; con 400 RU/s provisionadas ≈ $24/mes."
  type        = bool
  default     = false
}
variable "cosmos_location" {
  description = "Región de Cosmos DB (eastus rechazó capacidad en trial; eastus2 verificado para SWA)"
  type        = string
  default     = "eastus2"
}

# --- Azure Files (xusers/xclients de xid, en la cuenta del tfstate) ---
variable "files_storage_account_name" {
  description = "Cuenta existente donde vive el share (normalmente la del tfstate)"
  type        = string
  default     = ""
}
variable "files_share_name" {
  description = "File share con xusers.txt/xclients.txt (lo crea el pipeline antes del apply)"
  type        = string
  default     = "xid-data"
}
variable "files_storage_account_key" {
  description = "Key de la cuenta (sensible; llega por TF_VAR_ desde el pipeline, nunca en código)"
  type        = string
  sensitive   = true
  default     = ""
}

# --- SWA ---
variable "enable_swa" {
  type    = bool
  default = true
}
variable "swa_location" {
  description = "Región de Static Web Apps (eastus no lo soporta; eastus2 sí)"
  type        = string
  default     = "eastus2"
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
