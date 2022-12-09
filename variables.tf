variable "tenant_id" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "client_id" {
  description = "lz-demo service principal id"
  type        = string
}

variable "client_secret" {
  description = "lz-demo service principal secret"
  type        = string
  sensitive   = true
}

variable "host_os" {
  type = string
  # default = "windows"
}
