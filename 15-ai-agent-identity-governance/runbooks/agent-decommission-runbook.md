# AI Agent Decommission Runbook
## IDSentinel Solutions -- SCN-15

### Trigger Conditions
- Agent retirement or replacement
- Suspected compromise of client secret
- Ownership change requiring re-registration
- Scope change requiring permission re-review

### Step 1 -- Revoke the Client Secret
Navigate to Entra ID > App Registrations > IDS-AIAgent-GraphReporter > Certificates and Secrets.
Delete the active client secret. Confirm deletion. Screenshot the empty secrets panel.

### Step 2 -- Disable the App Registration
Navigate to Entra ID > App Registrations > IDS-AIAgent-GraphReporter > Overview.
Select Disable. This prevents new token issuance while preserving audit trail.
Do NOT delete the registration -- deletion removes sign-in log attribution.

### Step 3 -- Confirm Token Acquisition Failure
Run agent_token.py. Confirm 401 invalid_client response. Screenshot the error output.

### Step 4 -- Confirm Sign-In Log Entry
Navigate to Entra ID > Sign-in Logs > Service Principal Sign-ins.
Filter by Application: IDS-AIAgent-GraphReporter.
Confirm the final failed authentication event is present with error code and timestamp.
Export the log entry as SOC 2 decommission evidence.

### Validation Checklist
- [ ] Client secret panel shows no active secrets
- [ ] App registration status shows Disabled
- [ ] Token acquisition returns 401 invalid_client
- [ ] Sign-in log confirms final failed auth event
- [ ] Bitwarden entry for secret marked as decommissioned with date
