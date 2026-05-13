# INC-TYPE-001 — Identity Risk Response Runbook
**IDSentinel Solutions | Security Operations**
**Runbook Version:** 1.0
**Last Updated:** May 2026
**Owner:** IAM Engineering

---

## Purpose

Standardized response procedure for identity-based risk alerts surfaced by
Entra Identity Protection. Covers detection through post-incident documentation.
Applies to all P1 and P2 identity risk events.

---

## Severity Classification

| Risk Level | Entra Classification | Response SLA |
|------------|----------------------|--------------|
| P1 | High risk user or sign-in | Contain within 15 minutes |
| P2 | Medium risk user or sign-in | Contain within 60 minutes |
| P3 | Low risk | Investigate within 24 hours |

---

## Phase 1 — Detection

- [ ] Alert received from Entra Identity Protection (email, SIEM, or portal)
- [ ] Open **Entra Portal → Security → Identity Protection → Risky users**
- [ ] Identify affected user and note: display name, UPN, object ID, risk level
- [ ] Record **T+0** (detection timestamp) for MTTR tracking

---

## Phase 2 — Investigation

Run all queries via Graph API. Do not rely on portal-only triage.

- [ ] **Query 1** — Pull risky user detail (riskLevel, riskState, riskLastUpdatedDateTime)
- [ ] **Query 2** — Pull risk detection events (riskEventType, ipAddress, location)
- [ ] **Query 3** — Correlate sign-in logs (deviceDetail, CA policy results, MFA status)
- [ ] Determine: did the sign-in succeed? What access was granted?
- [ ] Document findings in incident ticket before proceeding

**Postman Collection:** `postman/IDSentinel-GraphAPI.postman_collection.json`

---

## Phase 3 — Containment

Execute immediately upon confirming suspicious activity.

- [ ] **Disable account** via Graph API PATCH `/users/{id}`
- [ ] **Revoke all sessions** via Graph API POST `/users/{id}/revokeSignInSessions`
- [ ] Record **T+containment** timestamp
- [ ] Screenshot PowerShell output as containment evidence

**Script:** `scripts/Invoke-IdentityRiskContainment.ps1`

---

## Phase 4 — Remediation

- [ ] Confirm riskState is still `atRisk` before remediating (GET riskyUsers/{id})
- [ ] **Reset password:**
  - Cloud-only user → Graph API PATCH passwordProfile
  - Directory-synced user → Reset via ADUC on domain controller
- [ ] **Re-enable account** via Graph API PATCH `/users/{id}`
- [ ] **Dismiss user risk** via Graph API POST `/identityProtection/riskyUsers/dismiss`
- [ ] Confirm riskState returns `dismissed` or `remediated`
- [ ] Record **T+remediation** timestamp

---

## Phase 5 — Post-Incident

- [ ] Calculate MTTR (T+remediation minus T+0)
- [ ] Complete RCA template: `templates/RCA-Template.md`
- [ ] Package all screenshots into `evidence/INC-YYYY-XXX/`
- [ ] File evidence as SOC 2 CC7.2 / CC7.3 documentation
- [ ] Identify and implement corrective actions
- [ ] Update this runbook if process gaps were identified

---

## Contacts

| Role | Responsibility |
|------|---------------|
| IAM Engineer on-call | Execute containment and remediation |
| Security Operations | Incident triage and ticket management |
| IT Management | Escalation for P1 events |