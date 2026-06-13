# SCN-14 Screenshots

| File | Stage | Description |
|---|---|---|
| SCN-14-01-managed-identity-enabled.png | Managed Identity Enablement | VM Identity blade showing system-assigned status On and Object ID |
| SCN-14-02-keyvault-rbac-mode.png | Key Vault Provisioning | Key Vault Access configuration tab showing Azure role-based access control selected |
| SCN-14-03-403-before-role-assignment.png | Break/Fix | PowerShell output showing 403 Forbidden on secret retrieval before role assignment |
| SCN-14-04-role-assignment.png | Role Assignment | Key Vault IAM blade showing Key Vault Secrets User role assigned to managed identity principal |
| SCN-14-05-successful-retrieval.png | Validation | PowerShell output showing successful secret retrieval with no credentials in script |
| SCN-14-06-keyvault-audit-log.png | Audit Trail | Log Analytics query results showing SecretGet event with managed identity Object ID as caller |
| SCN-14-07-user-assigned-identity.png | User-Assigned Identity | Standalone user-assigned managed identity resource in Azure portal |
| SCN-14-08-both-identity-types.png | Identity Comparison | VM Identity blade showing both system-assigned and user-assigned identities configured |
