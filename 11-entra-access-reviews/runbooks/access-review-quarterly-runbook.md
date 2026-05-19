# Quarterly Access Review Runbook
## IDSentinel Solutions — GRP-SEC-PrivilegedUsers
**Scenario 11 | Entra ID Identity Governance**

---

## Purpose

This runbook governs the quarterly access recertification cycle for
GRP-SEC-PrivilegedUsers. It defines the end-to-end process for the
IAM team — from pre-review preparation through post-review evidence
packaging — ensuring the review is completed consistently, on schedule,
and produces SOC 2-compliant audit evidence.

---

## Schedule

| Quarter | Review Window Opens | Review Window Closes | IAM Evidence Due |
|---------|--------------------|--------------------|-----------------|
| Q1      | January 1          | January 14          | January 17      |
| Q2      | April 1            | April 14            | April 17        |
| Q3      | July 1             | July 14             | July 17         |
| Q4      | October 1          | October 14          | October 17      |

Review is auto-triggered by Entra ID per the configured schedule.
IAM team is responsible for monitoring completion and exporting evidence.

---

## Roles and Responsibilities

| Role | Responsibility |
|------|---------------|
| IAM Engineer | Pre-review audit, monitor completion, export evidence, escalate non-response |
| Manager (Reviewer) | Approve or deny access for each direct report within 14 days |
| Group Owner (Fallback) | Review members whose manager attribute is unset |
| Security Manager | Sign off on SOC 2 evidence package before submission |

---

## Pre-Review Checklist (Complete Before Review Window Opens)

Run 3–5 business days before the scheduled start date.

- [ ] Run `Get-PrivilegedGroupBaseline.ps1` — export and archive the membership snapshot
- [ ] Run `Get-PrivilegedGroupBaseline.ps1 -CheckManagers` — verify all members have manager attribute set
- [ ] For any member with no manager: manually set manager in Entra ID OR confirm group owner is configured as fallback
- [ ] Confirm the Access Review appears as "Not Started" in Identity Governance → Access Reviews
- [ ] Confirm review scope, reviewer type, and auto-enforcement settings are unchanged from last cycle
- [ ] Archive baseline CSV to: `audit-exports\privileged-group-baseline_YYYY-MM-DD.csv`

---

## During Review Window (Day 1 – Day 14)

**Day 1:**
- [ ] Confirm review status changes to "In Progress" in the portal
- [ ] Confirm reviewer notification emails are delivered (check one manager mailbox)
- [ ] Log review start in the change record

**Day 7 (Mid-Review Check):**
- [ ] Check review completion percentage in the portal
- [ ] Identify any reviewers who have not responded
- [ ] Send a courtesy reminder to non-responding managers via email

**Day 12 (Pre-Close Warning):**
- [ ] Send final reminder to all non-responding reviewers
- [ ] Inform non-responders that non-response will trigger automatic access removal per policy

---

## Post-Review Checklist (Complete Within 3 Days of Review Close)

- [ ] Confirm review status is "Completed" in the portal
- [ ] Run `Export-AccessReviewAuditTrail.ps1` — export decisions and justifications
- [ ] Run `Get-PostReviewMembershipDelta.ps1 -BaselineCsvPath <baseline file>` — export before/after comparison
- [ ] Verify auto-enforcement ran: denied members and non-responders no longer appear in group membership
- [ ] If any removal did NOT occur: manually remove the member and document the manual action
- [ ] Archive all exports to the evidence package folder
- [ ] Submit evidence package to Security Manager for SOC 2 sign-off

---

## SOC 2 Evidence Package Contents

Each completed cycle should produce the following files:

| File | Source | SOC 2 Control |
|------|--------|---------------|
| `privileged-group-baseline_YYYY-MM-DD.csv` | Get-PrivilegedGroupBaseline.ps1 | CC6.3 — baseline state |
| `access-review-audit-trail_YYYY-MM-DD.csv` | Export-AccessReviewAuditTrail.ps1 | CC6.2, CC6.3 — decisions + justifications |
| `membership-delta_YYYY-MM-DD.csv` | Get-PostReviewMembershipDelta.ps1 | CC6.3 — enforcement outcome |
| Entra portal screenshot — review status Completed | Manual screenshot | Supporting evidence |

Archive all files to: `\\idsentinel-share\SOC2-Evidence\Access-Reviews\YYYY-QN\`

---

## Escalation Procedures

**Manager does not respond by Day 12:**
1. Send direct email reminder with subject: `ACTION REQUIRED: Access Review Closing in 48 Hours`
2. CC the manager's manager
3. Document the escalation in the change record
4. If still no response by close: auto-deny applies per policy — log the auto-denial in the evidence package

**Group owner is unavailable as fallback:**
1. IAM Engineer performs the review on behalf of the group owner
2. Document the reason and obtain written approval from Security Manager
3. Note in the audit trail CSV as "IAM Engineer — emergency fallback reviewer"

**Auto-enforcement does not trigger:**
1. Check: Settings → Apply Results → confirm "Auto apply results" is still enabled
2. If misconfigured: manually remove denied members and document the manual action
3. Open a change record to re-enable auto-enforcement before the next cycle

---

## Common Issues

| Issue | Resolution |
|-------|-----------|
| Reviewer says they didn't receive email | Check their spam folder; verify their UPN matches manager attribute; re-send from portal |
| Manager attribute missing on a member | Set manager in Entra ID → user profile; review will route to group owner in the meantime |
| Denied member still in group after review close | Check "Apply Results" setting; manually remove; document |
| Review shows "Not Started" after scheduled date | Verify license — Entra ID P2 required; check review definition for correct start date |
| Non-member in the audit trail CSV | Check for nested group membership; review scope may include transitive members |
