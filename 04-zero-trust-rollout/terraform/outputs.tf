# =============================================================================
# outputs.tf
# IDSentinel Solutions - Zero Trust CA Policy Outputs
# =============================================================================

output "ca_policy_mfa_all_users_id" {
  description = "ID of the MFA All Users CA policy"
  value       = azuread_conditional_access_policy.mfa_all_users.id
}

output "ca_policy_block_risky_id" {
  description = "ID of the Block High Risk Sign-ins CA policy"
  value       = azuread_conditional_access_policy.block_risky_signins.id
}

output "ca_policy_admin_portals_id" {
  description = "ID of the Admin Portal Restriction CA policy"
  value       = azuread_conditional_access_policy.restrict_admin_portals.id
}

output "ca_policy_block_legacy_id" {
  description = "ID of the Block Legacy Auth CA policy"
  value       = azuread_conditional_access_policy.block_legacy_auth.id
}