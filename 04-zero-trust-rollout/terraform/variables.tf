# =============================================================================
# variables.tf
# IDSentinel Solutions - Zero Trust CA Policy Variables
# =============================================================================

variable "break_glass_group_id" {
  description = "Object ID of GRP-SEC-BreakGlass group"
  type        = string
}

variable "privileged_users_group_id" {
  description = "Object ID of GRP-SEC-PrivilegedUsers group"
  type        = string
}

variable "legacy_auth_exempt_group_id" {
  description = "Object ID of GRP-SEC-LegacyAuthExempt group"
  type        = string
}