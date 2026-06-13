# SCN-14 Diagrams

| File | Description |
|---|---|
| SCN-14-managed-identity-flow.drawio | IMDS token acquisition and Key Vault authorization flow -- swim lane diagram |

## Diagram Notes

The architecture diagram should use swim lanes for:
- Azure VM (workload)
- Instance Metadata Service (IMDS)
- Microsoft Entra ID
- Azure Key Vault
- Log Analytics Workspace

Show the token request from the VM to IMDS, the token issuance from Entra ID,
the secret request to Key Vault with the bearer token, the RBAC check, and the
audit event forwarded to Log Analytics.

Add a cross-cloud reference callout linking to the SCN-09 AWS STS pattern.
