# Scenario 01 — MFA Bypass via Legacy Authentication

## 🏢 Business Problem

IDSentinel Solutions recently completed a company-wide MFA rollout across 
Microsoft Entra ID. Following the rollout, the Security team identified a 
critical gap during a routine sign-in log review: a significant number of 
users were still authenticating via legacy protocols — SMTP, IMAP, POP3, 
and Basic Auth — which completely bypass MFA enforcement.

An internal audit confirmed that several third-party email clients and 
older line-of-business applications were configured to use Basic 
Authentication, meaning a stolen credential alone was sufficient to grant 
full mailbox and application access with no additional verification 
required.

This is a direct violation of IDSentinel's Zero Trust initiative and 
creates unacceptable risk of account compromise via credential stuffing 
and password spray attacks.

---

## ⚠️ Risk

- MFA rendered ineffective for any account using legacy authentication
- No visibility into legacy auth attempts without explicit log filtering
- Active threat vector: password spray attacks targeting legacy endpoints
- Non-compliant with IDSentinel's Zero Trust access initiative
- Potential compliance exposure under SOC 2 Type II controls

---

## 🎯 Scope

- **Affected users:** All 1,066 employees across all departments
- **Affected protocols:** SMTP Auth, IMAP, POP3, Basic Authentication
- **Target:** Block all legacy authentication org-wide within 48 hours
- **Exception process:** Document and track any legitimate exemptions

---

## 🔧 Solution Design

A Conditional Access policy will be implemented to block all legacy 
authentication protocols across the organization. The rollout follows 
a staged approach to minimize business disruption:

**Stage 1 — Audit Mode (Report-Only)**
Deploy policy in report-only mode for 24 hours to identify impacted 
users before enforcement begins.

**Stage 2 — Enforcement**
Switch policy to enabled after reviewing report-only sign-in logs and 
notifying impacted teams.

**Key Design Decisions:**
- Block condition targets the "Other clients" and legacy auth client 
  app filters which cover all legacy protocol sign-ins
- Break-glass accounts (GRP-SEC-BreakGlass) excluded from policy
- Exemption group (GRP-SEC-LegacyAuthExempt) created for any 
  time-limited exceptions requiring change control approval
- Policy scoped to all users with targeted exclusions only

---

## 🛠️ Implementation

### Prerequisites
- Microsoft Entra ID P1 or P2 license
- Conditional Access Administrator or Security Administrator role
- Sign-in logs reviewed prior to enforcement

### Step 1 — Review Legacy Auth Sign-in Logs

Before deploying the policy, baseline the current legacy auth volume 
using the Sign-in logs and the PowerShell audit script.

![Baseline Audit](./screenshots/01-baseline-audit.png)

### Step 2 — Deploy Policy in Report-Only Mode

![Policy Report Only Config](./screenshots/02-policy-report-only-config.png)
![Policy Report Only Confirmed](./screenshots/03-policy-report-only-confirmed.png)

### Step 3 — Validate Policy with What If Tool

Prior to enforcement, the What If tool was used to simulate legacy auth 
sign-in scenarios and confirm the policy would block as expected.

![What If Would Block](./screenshots/04-whatif-would-block.png)
![What If Other Clients](./screenshots/04b-whatif-other-clients.png)

### Step 4 — Switch Policy to Enabled

![Policy Enabled](./screenshots/05-policy-enabled.png)

### Step 5 — Post-Enforcement Validation

What If tool confirmed policy enforcing block on all legacy auth 
client types. Audit script re-run confirmed zero legacy auth 
sign-ins post-enforcement.

![What If Enforced Block](./screenshots/06-whatif-enforced-block.png)
![Post Enforcement Audit](./screenshots/07-post-enforcement-audit.png)

---

## ✅ Outcome

- Conditional Access policy deployed in report-only mode for validation
- What If tool confirmed policy would block all legacy authentication 
  attempts across Exchange ActiveSync and Other client types before 
  enforcement
- Policy switched to enabled — legacy authentication now blocked org-wide
- Post-enforcement audit script detected 1 legacy auth attempt via 
  Authenticated SMTP from a privileged account during policy testing
- Account flagged, temporarily added to GRP-SEC-LegacyAuthExempt with 
  30-day review window pending mail client reconfiguration to modern auth
- Audit script exported full CSV report for compliance documentation
- Zero unauthorized legacy auth attempts detected post-enforcement

## 📊 Audit Results

| Metric | Value |
|--------|-------|
| Audit period | 7 days |
| Total sign-in events | 495 |
| Legacy auth attempts detected | 1 |
| Unique users flagged | 1 |
| Protocol | Authenticated SMTP |
| Result | Detected and flagged — exemption granted pending remediation |

## 📁 Files

| File | Description |
|------|-------------|
| `scripts/Get-LegacyAuthReport.ps1` | Audits legacy auth sign-ins via Graph API |
| `diagrams/ca-policy-flow.png` | Conditional Access decision flow diagram |
| `screenshots/` | Evidence of implementation at each stage |

---

## 🔗 References

- [Microsoft: Block legacy authentication with Entra ID CA](https://learn.microsoft.com/en-us/entra/identity/conditional-access/block-legacy-authentication)
- [Microsoft: What are legacy authentication protocols](https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-conditions)