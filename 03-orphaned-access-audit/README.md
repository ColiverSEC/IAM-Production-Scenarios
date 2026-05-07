# Scenario 03 — Orphaned Access Audit

## 🏢 Business Problem

IDSentinel Solutions' annual SOC 2 Type II audit flagged a critical 
finding: terminated employees and contractors were retaining access to 
company systems and applications after their offboarding date. A sample 
review of 50 accounts revealed that 12 former employees still had active 
Entra ID accounts with valid group memberships and application 
assignments — some dating back over 90 days post-termination.

Additionally, the audit identified a large number of guest (B2B) 
accounts that had been invited for project work but never cleaned up, 
and several groups with no designated owner — meaning no one was 
accountable for reviewing or approving access.

---

## ⚠️ Risk

- Former employees retaining access to sensitive systems post-offboarding
- Stale guest accounts with no expiration or review process
- Ownerless groups creating ungoverned access assignments
- Direct SOC 2 Type II audit finding requiring remediation
- Potential data exfiltration risk from orphaned privileged accounts

---

## 🎯 Scope

- All Entra ID user accounts synced from Active Directory
- All cloud-only guest (B2B) accounts
- All security groups with no designated owner
- Accounts inactive for 30+ days with active group memberships

---

## 🔧 Solution Design

A PowerShell script using Microsoft Graph API will automate the 
detection of four categories of orphaned access:

1. **Disabled AD accounts** still synced to Entra with active group memberships
2. **Stale guest accounts** not seen in 30+ days with active assignments
3. **Ownerless groups** with active members but no designated owner
4. **Accounts with no sign-in activity** in 90+ days

The script exports a full CSV report for compliance documentation and 
produces a remediation priority list for the IAM team.

---

## 🛠️ Implementation

### Step 1 — Run Orphaned Access Audit Script

📸 *Screenshot: Script output showing orphaned accounts detected*

### Step 2 — Review CSV Export

📸 *Screenshot: CSV report opened showing flagged accounts*

### Step 3 — Remediate Findings

📸 *Screenshot: Disabled accounts removed from groups in Entra*

### Step 4 — Ownerless Groups Assigned Owners

📸 *Screenshot: Group owner assigned in Entra admin center*

---

## ✅ Outcome

- Audit script detected all four categories of orphaned access
- CSV report exported for SOC 2 compliance documentation
- Remediation completed within 24-hour SLA
- Ownerless groups assigned designated owners
- Access review process documented and scheduled quarterly

## 📊 Audit Results

*(To be populated after script execution)*

---

## 📁 Files

| File | Description |
|------|-------------|
| `scripts/Get-OrphanedAccessReport.ps1` | Main audit script — detects all orphaned access categories |
| `diagrams/orphaned-access-flow.png` | Audit and remediation workflow diagram |
| `screenshots/` | Evidence of findings and remediation |

---

## 🔗 References

- [Microsoft: Access reviews in Entra ID](https://learn.microsoft.com/en-us/entra/id-governance/access-reviews-overview)
- [Microsoft: Manage stale guest accounts](https://learn.microsoft.com/en-us/entra/identity/users/clean-up-stale-guest-accounts)