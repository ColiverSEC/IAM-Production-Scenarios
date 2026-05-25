# SOC 2 Evidence — Scenario 13
# SCIM Provisioning: Entra ID → AWS IAM Identity Center

## Control Mapping

| SOC 2 Control | Description | Evidence |
|---------------|-------------|----------|
| CC6.2 | Logical access provisioning tied to identity lifecycle | Provisioning logs showing automated Joiner/Mover/Leaver events |
| CC6.3 | Logical access controls — access removal on offboarding | Leaver test: disabled Entra account → user removed from IAM Identity Center |

## Evidence Checklist

- [x] Screenshot: SCIM endpoint enabled in AWS IAM Identity Center → 02-scim-endpoint-bearer-token.png
- [x] Screenshot: Entra provisioning logs — initial sync → 09-initial-provisioning-logs.png
- [x] Screenshot: Joiner event — user provisioned within one cycle → 12a, 12b, 12c
- [x] Screenshot: Mover event — group change propagated, permission set updated → 13a, 13b, 13c
- [x] Screenshot: Leaver event — abonavita disabled in AD/Entra, deprovisioned from IAM Identity Center → 14a, 14b, 14c
- [x] Screenshot: All 13 IAM Identity Center users show Created by: SCIM — zero manual accounts → 14c
- [x] Export: Provisioning logs CSV from Entra portal
- [x] Script: audit-stale-assignments.ps1 executed — findings documented below
- [x] Script: validate-scim-pipeline.ps1 executed — pipeline validated clean

## Notes

- Test user for JML lifecycle validation: abonavita@IDSentinelSolutions.com
- IAM Identity Center region: us-east-2
- SCIM provisioning confirmed automated for all 13 users — no manual provisioning performed
- Leaver deprovisioning triggered by AD account disable → Entra Connect sync → SCIM cycle

## Script Execution Results

### audit-stale-assignments.ps1 — 2026-05-24
- 13 users audited in IAM Identity Center
- 12 Active in Entra
- 1 stale assignment identified: abonavita@IDSentinelSolutions.com (Disabled in Entra)
- Status: [!] ACTION REQUIRED — intentional, abonavita is the Leaver test user
- Evidence: audit-stale-assignments-output.png

### validate-scim-pipeline.ps1 — 2026-05-24
- Initial run: [FAIL] — amolino@IDSentinelSolutions.com found in GRP-AWS-Engineering
  in Entra but missing from IAM Identity Center
- Root cause: amolino account was disabled in Entra, blocking SCIM provisioning
- Remediation: account re-enabled in Entra, on-demand provisioning cycle triggered
- Second run: [PASS] — all 14 Entra group members confirmed present in IAM Identity Center
- Evidence: validate-scim-pipeline-output.png