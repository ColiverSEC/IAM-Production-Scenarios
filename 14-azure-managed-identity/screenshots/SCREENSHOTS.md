# Screenshots -- Scenario 14

Capture screenshots at each implementation step.
Name them to match the README references exactly.

| Filename | Step | Description |
|----------|------|-------------|
| 01-vm-managed-identity-enabled.png | Step 1 | Azure portal -- VM Overview showing System assigned managed identity: On |
| 02-vm-identity-principal-id.png | Step 1 | CLI output of az vm identity show -- principalId captured |
| 03-keyvault-secret-created.png | Step 2 | Azure portal -- Key Vault Secrets blade showing db-connection-string |
| 04-rbac-assignment-kv-secrets-user.png | Step 3 | CLI output confirming role assignment creation |
| 05-rbac-assignment-portal-verified.png | Step 3 | Azure portal -- Key Vault IAM blade showing Key Vault Secrets User assigned to managed identity |
| 06-imds-token-acquired.png | Step 4a | VM shell -- IMDS curl response with truncated token printed |
| 07-secret-retrieved-zero-credentials.png | Step 4b | VM shell -- Secret value printed with no credentials in session |
| 08-diagnostic-settings-enabled.png | Step 5 | Azure portal -- Key Vault Diagnostic settings showing AuditEvent to Log Analytics |
| 09-audit-log-secret-retrieval.png | Step 6 | Log Analytics query result -- SecretGet event with managed identity OID as caller |

## Screenshot Tips

- Step 1: capture both the portal identity tab AND the CLI output showing principalId
- Step 3 portal: confirm the scope column shows the Key Vault resource -- not subscription or resource group
- Step 4b: capture the VS Code terminal showing Retrieve-Secret.ps1 output -- secret value printed, no credentials visible anywhere in the session
- Step 6: ensure identity_claim_oid_g column is visible and matches the principal ID from Step 1
