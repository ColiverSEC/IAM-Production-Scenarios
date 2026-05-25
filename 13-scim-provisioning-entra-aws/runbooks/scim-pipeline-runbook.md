# Runbook — SCIM Provisioning Pipeline: Entra ID → AWS IAM Identity Center

## Purpose
Operational runbook for managing and troubleshooting the SCIM provisioning
pipeline between Microsoft Entra ID and AWS IAM Identity Center.

## Provisioning a New Group

1. Create the group in Active Directory following naming convention: GRP-AWS-<TeamName>
2. Allow Entra Connect to sync the group (up to 30 minutes)
3. In Entra portal → Enterprise Apps → AWS IAM Identity Center → Provisioning
4. Under Assignments, add the new group to scope
5. Save and trigger an on-demand provisioning cycle
6. In AWS IAM Identity Center, assign the group to the target account with the correct permission set
7. Verify: confirm group and members are visible in IAM Identity Center

## Bearer Token Renewal

The SCIM bearer token does not auto-rotate. If provisioning fails with a
401 Unauthorized error:

1. In AWS IAM Identity Center → Settings → Identity source
2. Under Automatic provisioning, click Regenerate token
3. Copy the new token immediately — it is only shown once
4. In Entra portal → Enterprise Apps → AWS IAM Identity Center → Provisioning
5. Under Admin Credentials, paste the new token into Secret Token
6. Click Test Connection → Save

## Troubleshooting

| Symptom | Check | Resolution |
|---------|-------|------------|
| User not appearing in IAM Identity Center | Entra provisioning logs | Verify user is in a scoped group; trigger on-demand cycle |
| Provisioning cycle not running | Entra provisioning status | Confirm mode is Automatic; trigger on-demand cycle |
| User deprovisioned unexpectedly | Group membership in Entra | Confirm user is still a member of a scoped group |
| SCIM 401 Unauthorized error | Bearer token | Regenerate token in AWS — see Bearer Token Renewal above |
| Group synced but no AWS access | Permission set assignment | Confirm group is assigned to the account with correct permission set in IAM Identity Center |
| AD group change not propagating | Entra Connect sync | Run Start-ADSyncSyncCycle -PolicyType Delta, then trigger on-demand provisioning |