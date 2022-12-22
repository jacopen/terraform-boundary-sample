terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = ">=1.1.0"
    }
  }
}

provider "boundary" {
  auth_method_id                  = var.global_auth_method_id
  password_auth_method_login_name = var.global_password_auth_method_login_name
  password_auth_method_password   = var.global_password_auth_method_password
  addr                            = var.boundary_addr
}

resource "boundary_scope" "global" {
  global_scope = true
  scope_id     = "global"
}
