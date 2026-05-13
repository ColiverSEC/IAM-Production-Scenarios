# Root Cause Analysis — INC-2026-007
**IDSentinel Solutions | Security Operations**
**Date:** May 13, 2026
**Prepared by:** Cleveland Oliver, IAM Engineer

---

## Incident Summary

| Field | Value |
|-------|-------|
| Incident ID | INC-2026-007 |
| Severity | P2 — Medium Risk |
| Affected User | wking@IDSentinelSolutions.com |
| Detection Source | Entra Identity Protection |
| Risk Event Type | anonymizedIPAddress (Tor exit node) |
| Detection Time | 2026-05-13 UTC |
| Containment Time | See evidence timestamps |
| MTTR | See evidence timestamps |
| SOC 2 Controls | CC7.2, CC7.3 |
| Evidence Package | `evidence/INC-2026-007/` |

---

## What Happened

The account `wking@IDSentinelSolutions.com` was used to authenticate through
a Tor exit node, triggering an anonymizedIPAddress risk detection in Entra
Identity Protection. The sign-in succeeded because no risk-based Conditional
Access policy was configured to challenge or block Medium risk sign-ins.
Identity Protection flagged the user at Medium risk level.

---

## Root Cause

Risk-based Conditional Access policy was scoped to **High risk only**.
Medium risk sign-ins were logged and flagged in Identity Protection but
were not challenged with MFA or blocked — allowing the Tor-sourced
authentication to succeed without additional verification.

---

## Contributing Factors

- No automated alerting or ticketing configured on Identity Protection events.
  Analyst discovered the alert during manual portal review.
- wking is a directory-synced user — password cannot be reset via Graph API,
  requiring a manual on-premises reset via ADUC before account re-enable.

---

## Remediation Actions Taken

| Step | Action | Method |
|------|--------|--------|
| 1 | Account disabled | Graph API — PATCH /users/{id} |
| 2 | All active sessions revoked | Graph API — POST /users/{id}/revokeSignInSessions |
| 3 | Password reset | On-premises ADUC — directory-synced user |
| 4 | Account re-enabled | Graph API — PATCH /users/{id} |
| 5 | User risk dismissed | Graph API — POST /identityProtection/riskyUsers/dismiss |

---

## Corrective Actions

| # | Action | Owner | Status |
|---|--------|-------|--------|
| 1 | Update CA policy to challenge sign-ins at Medium risk (not just High) | IAM Engineer | Complete |
| 2 | Document hybrid password reset process in runbook | IAM Engineer | Complete |
| 3 | Playbook added to SOC runbook library as INC-TYPE-001 | IAM Engineer | Complete |

---

## Lessons Learned

- Risk-based CA policies should cover Medium risk as a minimum threshold.
  High-only coverage leaves a significant gap for events like anonymized IP
  sign-ins which frequently score at Medium.
- Directory-synced users require an on-prem password reset step that must
  be explicitly called out in runbooks to avoid remediation delays.
- Graph API automation reduced containment time significantly compared to
  manual portal navigation — account disable and session revocation executed
  in under 2 minutes once the script was run.

---

## Evidence

All screenshots filed in `evidence/INC-2026-007/`:

| File | Description |
|------|-------------|
| 01-tor-signin.png | Simulated risky sign-in via Tor Browser |
| 02-identity-protection-alert.png | Identity Protection alert showing user at risk |
| 03-api-permissions.png | App registration permissions updated for investigation |
| 04-risky-user-query.png | Graph API — risky user detail |
| 05-risk-detection-query.png | Graph API — risk detection events |
| 06-signin-log-query.png | Graph API — sign-in log correlation |
| 07-containment-output.png | PowerShell — account disable and session revocation |
| 08-risk-state-atrisk.png | Graph API — risk state confirmed atRisk pre-remediation |
| 09-password-reset.png | On-premises password reset via ADUC |
| 10-account-reenabled.png | PowerShell — account re-enabled |
| 11-risk-dismissed.png | Graph API — risk dismissal confirmed |
| 12-risk-state-remediated.png | Graph API — risk state confirmed dismissed |
| 13-rca-document.png | This document |
| 14-evidence-package.png | Evidence folder contents |