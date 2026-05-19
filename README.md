# 🛡️ IAM Production Scenarios

Real-world Identity and Access Management scenarios simulated in a homelab environment — built to mirror the production problems IAM Engineers face daily.

Each scenario includes a business problem, solution design, implementation evidence, and documented outcome — structured as production case studies, not how-to guides.

---

## 🏢 Lab Environment

| Component | Detail |
|-----------|--------|
| On-Prem | Windows Server 2019 (Active Directory DS) |
| Cloud Identity | Microsoft Entra ID (M365 Developer Tenant) |
| CIAM Platform | Auth0 (Okta Customer Identity Cloud) |
| Workforce IAM | Okta Developer Edition |
| SIEM | Splunk Enterprise 10.2.3 |
| Domain | IDSentinelSolutions.com (hybrid — Entra Connect synced) |
| Tools | PowerShell, Terraform, Postman, Python, SAML Tracer, SPL |

---

## 📁 Scenarios

| # | Scenario | Problem Solved | Key Skills |
|---|----------|----------------|------------|
| 01 | [MFA Bypass via Legacy Auth](./01-mfa-bypass-legacy-auth/) | Legacy protocols bypassing MFA controls org-wide | Conditional Access, Sign-in Logs, What-If, Block Legacy Auth |
| 02 | [App Migration: Legacy IdP → Okta](./02-app-migration-okta/) | M&A requires migrating apps off legacy SSO | SAML, Okta, Attribute Mapping, Cutover Planning |
| 03 | [Orphaned Access Audit](./03-orphaned-access-audit/) | Audit found stale users retaining access post-offboarding | Graph API, PowerShell, Access Governance |
| 04 | [Zero Trust Rollout](./04-zero-trust-rollout/) | Executive mandate to implement Zero Trust for 1,000-person org | CA Policies, PIM, Compliant Devices, Terraform |
| 05 | [SCIM Provisioning Pipeline](./05-scim-provisioning/) | Manual provisioning causing access delays and errors | SCIM, Lifecycle Automation, Okta Workflows |
| 06 | [OAuth2 API Integration](./06-oauth2-api-integration/) | Need automated reporting on identity risk posture | Graph API, OAuth2, Python, Postman |
| 07 | [Identity Risk Response Playbook](./07-identity-risk-response-playbook/) | No standardized process for responding to Identity Protection alerts | Entra Identity Protection, Graph API, NIST IR, SOC 2 |
| 08 | [CIAM Login Platform with Auth0](./08-scenario-ciam-b2c/) | Customer-facing app needs secure, branded login with social federation and API protection | Auth0, OIDC, OAuth2, JWT, Google Federation, MFA |
| 09 | [AWS IAM Least Privilege Implementation](./09-aws-iam-least-privilege/) | Overprivileged AWS roles increase risk of lateral movement and privilege escalation | AWS IAM, Least Privilege, IAM Policies, CloudTrail |
| 10 | [Identity Threat Detection Pipeline](./10-identity-threat-detection/) | No centralized SOC visibility into identity threats — MFA fatigue, impossible travel, after-hours PIM, and legacy auth spikes going undetected | Splunk, SPL, Graph API, HEC, Python, MITRE ATT&CK, SOC 2 |
| 11 | [Entra Access Reviews](./11-entra-access-reviews/) | 188-member privileged group unreviewed since provisioning — SOC 2 CC6.3 finding, no documented approval trail, manager attribute unpopulated in AD | Entra Identity Governance, Access Reviews, AD PowerShell, Graph API, SOC 2 |
| 12 | [Entra ID + AWS SAML Federation](./12-entra-aws-saml-federation/) | AWS console access via long-lived IAM user credentials — Zero Trust violation and SOC 2 finding; no documented SAML troubleshooting path | SAML 2.0, Entra ID SSO, AWS IAM Federation, STS, SAML Tracer, SOC 2 |

---

## 🔍 How Each Scenario Is Structured

Every scenario folder follows this format:

- **README.md** — Business problem, constraints, solution design, outcome metrics
- **scripts/** — PowerShell, Python, or Terraform used
- **screenshots/** — Evidence of implementation at each stage
- **diagrams/** — Architecture or flow diagrams (draw.io)
- **postman/** — API collections where applicable
- **runbooks/** — SOC runbooks and operational procedures (where applicable)

---

## 🧰 Skills Demonstrated

| Skill Area | Scenarios |
|------------|-----------|
| Conditional Access & MFA | 01, 04 |
| Identity Governance & Access Reviews | 03, 11 |
| Privileged Access Management (PIM) | 04, 10 |
| Zero Trust Architecture | 04 |
| PowerShell & Graph API Automation | 03, 04, 06, 07, 10, 11, 12 |
| OAuth2 / OIDC / JWT | 06, 08 |
| CIAM & Customer Identity | 08 |
| Social Identity Federation | 08 |
| SAML 2.0 / SSO Federation | 02, 12 |
| API Protection with Bearer Tokens | 06, 08 |
| Terraform / Policy-as-Code | 04 |
| Identity Lifecycle / JML | 03, 11 |
| Incident Response (P1/P2 Runbooks) | 07 |
| SIEM Integration & Log Pipeline | 10 |
| Threat Detection & SPL | 10 |
| MITRE ATT&CK Mapping | 07, 10 |
| SOC 2 Audit Evidence | 03, 07, 09, 10, 11, 12 |
| AWS IAM & Role Assumption | 09 |
| AWS SAML Federation & STS | 12 |
| Hybrid Identity (AD + Entra) | 11 |
| SCIM Provisioning | 05 (in progress) |

---

## 🔗 Related Repos

| Repo | Purpose |
|------|---------|
| [Enterprise IAM Lab](https://github.com/ColiverSEC/Enterprise-IAM-Lab) | Foundational IAM concepts, protocol references, how-to guides |
| [M365 Security Lab](https://github.com/ColiverSEC/Microsoft-365-Security-Lab) | Microsoft Purview, Defender, Intune |