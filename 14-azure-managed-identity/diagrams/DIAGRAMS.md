# Diagrams -- Scenario 14

## managed-identity-architecture.png

Create in draw.io (diagrams.net). Dark theme with blue accent colors.

Layout (left to right):

LEFT -- Workload
- Box: Azure VM (vm-idsentinel-nhid)
- Sub-label: System-Assigned Managed Identity
- Note: No credentials stored on disk

CENTER -- Authentication Flow (numbered arrows)
1. App calls IMDS endpoint (169.254.169.254) -- internal only, unreachable externally
2. Azure AD issues short-lived OAuth2 token scoped to vault.azure.net
3. App calls Key Vault REST API with Bearer token
4. Key Vault validates token against Azure AD
5. Key Vault returns secret value

RIGHT -- Azure Services
- Box: Azure AD -- validates managed identity, issues token
- Box: Azure Key Vault (kv-idsentinel-nhid)
  -- RBAC: Key Vault Secrets User (scope: vault)
  -- Secret: db-connection-string
- Box: Log Analytics (law-idsentinel-nhid)
  -- AuditEvent logs -- SecretGet captured

BOTTOM -- Anti-Pattern Callout (red/orange border)
Replaces:
  - AD service account with non-expiring password
  - Hardcoded API key in application code
  - App registration secret with no rotation

Style: Dark background, blue accents. Dashed arrow for IMDS call (internal).
Label arrow 2: "Short-lived token (scoped to vault.azure.net)"
