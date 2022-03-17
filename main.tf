terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "=1.0.6"
    }
  }
}

variable "global_auth_method_id" {}
variable "global_password_auth_method_login_name" {}
variable "global_password_auth_method_password" {}
variable "boundary_addr" {}
variable "recovery_kms_hcl" {}

provider "boundary" {
  auth_method_id                  = var.global_auth_method_id
  password_auth_method_login_name = var.global_password_auth_method_login_name
  password_auth_method_password   = var.global_password_auth_method_password
  addr                            = var.boundary_addr
  recovery_kms_hcl                = var.recovery_kms_hcl
}

resource "boundary_scope" "global" {
  global_scope = true
  scope_id     = "global"
}

## Org
resource "boundary_scope" "wells_org" {
  name                     = "wells"
  description              = "Organization for wells"
  scope_id                 = boundary_scope.global.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

## Admin role for org
resource "boundary_role" "wells_org_admin" {
  scope_id       = boundary_scope.global.id
  grant_scope_id = boundary_scope.wells_org.id
  grant_strings  = ["id=*;type=*;actions=*"]
  principal_ids  = ["u_auth"]
}

## Project
resource "boundary_scope" "wells_main_project" {
  name                   = "main"
  description            = "main project"
  scope_id               = boundary_scope.wells_org.id
  auto_create_admin_role = true
}

## Auth method
resource "boundary_auth_method" "password" {
  scope_id = boundary_scope.wells_org.id
  type     = "password"
}

## User and account
resource "boundary_account" "jacopen" {
  auth_method_id = boundary_auth_method.password.id
  type           = "password"
  login_name     = "jacopen"
  password       = "$uper$ecure"
}

resource "boundary_user" "jacopen" {
  name        = "jacopen"
  description = "jacopen user"
  account_ids = [boundary_account.jacopen.id]
  scope_id    = boundary_scope.wells_org.id
}

## Role
resource "boundary_role" "wells_org_read" {
  name          = "wells-org-read-only"
  description   = "Wells User - Non admin"
  principal_ids = [boundary_user.jacopen.id]
  grant_strings = ["id=*;type=*;actions=read"] # Read only for org
  scope_id      = boundary_scope.wells_org.id
}

resource "boundary_role" "wells_main_project_user" {
  name          = "wells-main-project-user"
  description   = "Main project member"
  principal_ids = [boundary_user.jacopen.id]
  grant_strings = ["id=*;type=*;actions=*"] # Grant all actions in the project scope
  scope_id      = boundary_scope.wells_main_project.id
}

## Target
resource "boundary_host_catalog" "bastions" {
  name        = "bastions"
  description = "bastions"
  scope_id    = boundary_scope.wells_main_project.id
  type        = "static"
}

resource "boundary_host" "bastion" {
  name            = "bastion"
  host_catalog_id = boundary_host_catalog.bastions.id
  address         = "10.9.8.171"
  type            = "static"
}

resource "boundary_host_set" "bastion_set" {
  name            = "bastion_set"
  host_catalog_id = boundary_host_catalog.bastions.id
  type            = "static"
  host_ids = [
    boundary_host.bastion.id,
  ]
}

resource "boundary_target" "bastion_ssh" {
  name         = "bastion-ssh"
  description  = "ssh to bastion"
  type         = "tcp"
  default_port = "22"
  scope_id     = boundary_scope.wells_main_project.id
  host_source_ids = [
    boundary_host_set.bastion_set.id
  ]
}
