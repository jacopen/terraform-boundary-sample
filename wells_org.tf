## Org
resource "boundary_scope" "wells_org" {
  name                     = "wells"
  description              = "Organization for wells"
  scope_id                 = boundary_scope.global.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

## Auth method
resource "boundary_auth_method" "password" {
  scope_id = boundary_scope.wells_org.id
  type     = "password"
}

resource "boundary_auth_method_oidc" "wells" {
  scope_id       = boundary_scope.wells_org.id
  api_url_prefix = "https://385842d9-adba-4aca-b704-e03c3e71fdf6.boundary.hashicorp.cloud"
  callback_url   = "https://385842d9-adba-4aca-b704-e03c3e71fdf6.boundary.hashicorp.cloud/v1/auth-methods/oidc:authenticate:callback"
  claims_scopes = [
    "email",
    "groups",
    "profile",
  ]
  client_id     = "0oa7q7l4j66XttHU55d7"
  client_secret = var.client_secret
  issuer        = "https://dev-14117963.okta.com"
  name          = "Okta"
  signing_algorithms = [
    "RS256",
  ]
  state = "active-public"
}

## Managed Group
resource "boundary_managed_group" "team_a" {
  name           = "teamA"
  auth_method_id = boundary_auth_method_oidc.wells.id
  filter         = "\"teamA\" in \"/userinfo/groups\""
}

resource "boundary_managed_group" "team_b" {
  name           = "teamB"
  auth_method_id = boundary_auth_method_oidc.wells.id
  filter         = "\"teamB\" in \"/userinfo/groups\""
}

## Role in Org
resource "boundary_role" "wells_org_admin" {
  name           = "Admin"
  scope_id       = boundary_scope.wells_org.id
  grant_scope_id = boundary_scope.wells_org.id
  grant_strings  = ["id=*;type=*;actions=*"]
  principal_ids  = ["u_auth"]
}

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


# Project
resource "boundary_scope" "wells_main_project" {
  name                   = "main"
  description            = "main project"
  scope_id               = boundary_scope.wells_org.id
  auto_create_admin_role = true
}

## Role in Project
resource "boundary_role" "team_a" {
  name          = "teamA-role"
  description   = "role for teamA"
  principal_ids = [boundary_managed_group.team_a.id]
  scope_id      = boundary_scope.wells_main_project.id
  grant_strings = [
    "id=*;type=*;actions=*",
  ]
}

resource "boundary_role" "team_b" {
  name          = "teamA-role"
  description   = "role for teamB"
  principal_ids = [boundary_managed_group.team_b.id]
  scope_id      = boundary_scope.wells_main_project.id
  grant_strings = [
    "id=*;type=*;actions=*",
  ]
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