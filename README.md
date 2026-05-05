# 🛡️ IAM Production Scenarios

Real-world Identity and Access Management scenarios simulated in a homelab environment — built to mirror the production problems IAM Engineers face daily.

Each scenario includes a business problem, solution design, implementation, and documented outcome.

---

## 🏢 Lab Environment

| Component | Detail |
|-----------|--------|
| On-Prem | Windows Server 2019 (Active Directory DS) |
| Cloud Identity | Microsoft Entra ID (M365 Developer Tenant) |
| IAM Platform | Okta Developer Edition |
| Domain | IDSentinelSolutions.com (hybrid — Entra Connect synced) |
| Tools | PowerShell, Terraform, Postman, Python, SAML Tracer |

---

## 📁 Scenarios

| # | Scenario | Problem Solved | Key Skills |
|---|----------|----------------|------------|
| 01 | [MFA Bypass via Legacy Auth](./01-mfa-bypass-legacy-auth/) | Legacy protocols bypassing MFA controls org-wide | Conditional Access, Sign-in Logs, Block Legacy Auth |
| 02 | [App Migration: Legacy IdP → Okta](./02-app-migration-okta/) | M&A requires migrating apps off legacy SSO | SAML, Okta, Attribute Mapping, Cutover Planning |
| 03 | [Orphaned Access Audit](./03-orphaned-access-audit/) | Audit found stale users retaining access post-offboarding | Graph API, PowerShell, Access Governance |
| 04 | [Zero Trust Rollout](./04-zero-trust-rollout/) | Executive mandate to implement Zero Trust for 500-person org | CA Policies, PIM, Compliant Devices, Terraform |
| 05 | [SCIM Provisioning Pipeline](./05-scim-provisioning/) | Manual provisioning causing access delays and errors | SCIM, Lifecycle Automation, Okta Workflows |
| 06 | [OAuth2 API Integration](./06-oauth2-api-integration/) | Need automated reporting on identity risk posture | Graph API, OAuth2, Python, Postman |

---

## 🔍 How Each Scenario Is Structured

Every scenario folder follows this format:

- **README.md** — Business problem, constraints, solution design, outcome
- **scripts/** — PowerShell, Python, or Terraform used
- **screenshots/** — Evidence of implementation
- **diagrams/** — Architecture or flow diagrams (draw.io)
- **postman/** — API collections where applicable

---

## 🔗 Related Repos

| Repo | Purpose |
|------|---------|
| [Enterprise IAM Lab](https://github.com/ColiverSEC/Enterprise-IAM-Lab) | Foundational IAM concepts, protocol references, how-to guides |
| [M365 Security Lab](https://github.com/ColiverSEC/Microsoft-365-Security-Lab) | Microsoft Purview, Defender, Intune |