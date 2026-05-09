# =============================================================================
# main.tf
# IDSentinel Solutions - Zero Trust Conditional Access Policies
# Terraform AzureAD Provider
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 04 - Zero Trust Rollout
# =============================================================================

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {
  tenant_id = "791eadd1-7519-44e0-8445-751a43c7bfff"
}

# =============================================================================
# DATA SOURCES - Reference existing groups by variable
# =============================================================================

data "azuread_group" "break_glass" {
  object_id = var.break_glass_group_id
}

data "azuread_group" "privileged_users" {
  object_id = var.privileged_users_group_id
}

data "azuread_group" "legacy_auth_exempt" {
  object_id = var.legacy_auth_exempt_group_id
}

# =============================================================================
# POLICY 1 - Require MFA for All Users
# =============================================================================

resource "azuread_conditional_access_policy" "mfa_all_users" {
  display_name = "Require MFA - All Users [Terraform]"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = [
        data.azuread_group.break_glass.object_id
      ]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# =============================================================================
# POLICY 2 - Block High Risk Sign-ins
# =============================================================================

resource "azuread_conditional_access_policy" "block_risky_signins" {
  display_name = "Block High Risk Sign-ins [Terraform]"
  state        = "enabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = [
        data.azuread_group.break_glass.object_id
      ]
    }

    sign_in_risk_levels = ["high"]
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

# =============================================================================
# POLICY 3 - Restrict Admin Portal Access
# =============================================================================

resource "azuread_conditional_access_policy" "restrict_admin_portals" {
  display_name = "Restrict Admin Portal Access [Terraform]"
  state        = "enabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["MicrosoftAdminPortals"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = [
        data.azuread_group.break_glass.object_id,
        data.azuread_group.privileged_users.object_id
      ]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

# =============================================================================
# POLICY 4 - Block Legacy Authentication
# =============================================================================

resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "Block Legacy Authentication [Terraform]"
  state        = "enabled"

  conditions {
    client_app_types = [
      "exchangeActiveSync",
      "other"
    ]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = [
        data.azuread_group.break_glass.object_id,
        data.azuread_group.legacy_auth_exempt.object_id
      ]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}