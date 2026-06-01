# App Migration Cutover Runbook
## IDSentinel Solutions -- Scenario 02
**Entra ID (Legacy SSO) -> Okta (Target SSO) | SAML 2.0 App Migration**
**Provisioning: AD -> Okta AD Agent (direct)**

---

## Purpose

This runbook governs the cutover execution for migrating the IDSentinel HR
Portal off Microsoft Entra ID SSO onto Okta. It defines the step-by-step
process, go/no-go criteria, rollback procedure, and post-cutover validation
required to execute a controlled migration with zero unplanned downtime.

Note: User provisioning (AD -> Okta via AD Agent) was completed prior to
this cutover. This runbook covers SSO migration only.

---

## Pre-Cutover Criteria (Go / No-Go Gate)

All items must be confirmed PASS before the cutover window opens.
Run pre-cutover-checklist.ps1 to validate programmatically.

| Criteria | Validated By | Status |
|----------|-------------|--------|
| AD Agent Active on IDS-DC | Okta Admin Console | [ ] |
| GRP-ACCESS-HRApps members Active in Okta | validate-saml-groups.ps1 | [ ] |
| Okta SAML app ACS URL correct | Manual verification | [ ] |
| Okta SAML app Entity ID correct | Manual verification | [ ] |
| All attribute statements mapped | Manual verification | [ ] |
| GRP-ACCESS-HRApps assigned to Okta app | Okta console | [ ] |
| SP metadata updated with Okta IdP XML | samltest.id | [ ] |
| SP-initiated SSO validated via Okta | SAML Tracer | [ ] |
| IdP-initiated SSO validated via Okta | SAML Tracer | [ ] |
| All SAML assertion checks passed (9/9) | SAML Tracer | [ ] |
| Legacy Entra config backed up / noted | Screenshot | [ ] |
| Rollback procedure reviewed | IAM engineer | [ ] |

---

## Cutover Steps

### Step 1 -- Confirm Maintenance Window
Notify affected users of the planned cutover window.
SSO will be unavailable for approximately 5 minutes during the SP metadata swap.

### Step 2 -- Take Final Screenshot of Legacy Entra SSO Config
Capture the current Entra SSO configuration as the rollback baseline.
Save to screenshots/05-cutover/ before making any changes.

### Step 3 -- Disable Legacy Entra SSO
In Entra ID -> Enterprise Applications -> IDSentinel HR Portal:
- Navigate to Single Sign-On
- Set SSO mode to Disabled (NOT deleted)
- Save the configuration

> WARNING: Disable only -- do NOT delete the app or SAML configuration.
> The configuration must be preserved for the 30-day rollback window.

### Step 4 -- Validate SP Routes to Okta
Test SP-initiated login from samltest.id.
Confirm browser redirects to Okta login page (not Entra).
Authentication should succeed.

### Step 5 -- Capture Post-Cutover SAML Assertion
Use SAML Tracer to capture the post-cutover assertion.
Confirm issuer = Okta Entity ID (not Entra).
Save screenshot to screenshots/05-cutover/21-post-cutover-validated.png

### Step 6 -- Confirm IdP-Initiated Flow
Test from Okta end-user dashboard.
HR Portal tile should launch samltest.id and display the decoded assertion.

### Step 7 -- Declare Go-Live
Migration complete. Notify affected users that SSO is live on Okta.

---

## Rollback Procedure

Execute if post-cutover validation fails or users report SSO failures.

### Rollback Steps
1. Re-enable legacy Entra SSO configuration:
   - Entra ID -> Enterprise Applications -> IDSentinel HR Portal
   - Set SSO mode back to SAML
   - Save

2. Revert SP metadata at samltest.id:
   - Re-upload the Entra IdP metadata XML (saved during baseline step)
   - SP now trusts Entra again

3. Validate SP-initiated login routes back through Entra

4. Notify affected users that SSO has been restored on the legacy IdP

5. Document rollback reason -- create post-incident review ticket

### Rollback Time Target
Under 15 minutes from decision to restore

---

## Post-Cutover Evidence Package (SOC 2)

| Artifact | Location |
|----------|----------|
| Pre-cutover checklist output (CSV) | scripts/pre-cutover-results-{date}.csv |
| Legacy Entra SSO disabled screenshot | screenshots/05-cutover/20-legacy-sso-disabled.png |
| Post-cutover SAML Tracer assertion | screenshots/05-cutover/21-post-cutover-validated.png |
| Group sync validation report (CSV) | scripts/group-sync-report-{date}.csv |
| This runbook | runbooks/app-migration-cutover-runbook.md |

---

## Contact

| Role | Responsibility |
|------|---------------|
| IAM Engineer | Execute cutover, validate, declare go-live |
| App Owner | Confirm application is functional post-cutover |
| Security Manager | Sign off on SOC 2 evidence package |
