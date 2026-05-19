# SAML SSO Break/Fix Runbook
## Scenario 12 — Entra ID + AWS SAML Federation
**IDSentinel Solutions | Cleveland Oliver**

---

## Purpose

This runbook is the first-response guide for SAML SSO failures on the Entra ID → AWS federation. It covers the three most common failure modes, their error signatures, how to diagnose using SAML Tracer, and the fix steps with target resolution times.

Use this runbook before escalating any SAML federation incident.

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| SAML Tracer (Chrome Extension) | Captures and decodes SAML requests and responses in real time |
| Entra ID portal access | To inspect and modify the enterprise app configuration |
| AWS IAM console access | To inspect the Identity Provider and role trust policy |
| AWS CLI (optional) | To run `validate-saml-federation.ps1` for automated pre-checks |

**Install SAML Tracer:** Chrome Web Store → search "SAML Tracer" → Install

---

## How to Capture a SAML Assertion with SAML Tracer

1. Open Chrome and click the SAML Tracer extension icon
2. The capture window opens — leave it open
3. In a new tab, navigate to `https://myapps.microsoft.com` and click the AWS tile
4. Watch SAML Tracer — requests are logged in real time
5. Look for requests with an orange **SAML** label — these are the assertion flows
6. Click on the POST to `https://signin.aws.amazon.com/saml`
7. Switch to the **SAML** tab in SAML Tracer to see the decoded assertion XML

---

## Failure Mode 1 — Destination Mismatch (Wrong ACS URL)

### Error signature
```
AuthnResponse received with invalid destination
```
Or the browser shows an error immediately after Entra redirects without loading the AWS console.

### SAML Tracer diagnosis
1. Capture the assertion as described above
2. In the SAML tab, search for `Destination`
3. Read the value: it will show the URL Entra sent the assertion to
4. Compare it to the AWS expected ACS URL: `https://signin.aws.amazon.com/saml`
5. If they don't match exactly — this is the cause

### Fix
1. Open Entra ID portal → Enterprise Applications → AWS app
2. Single Sign-On → Basic SAML Configuration → Edit
3. Set **Reply URL (ACS URL)** to exactly: `https://signin.aws.amazon.com/saml`
4. Save and retry login

**Target resolution time:** 3 minutes

### Why this happens in production
- Copy-paste error during initial setup
- Another admin edited the ACS URL for a different AWS account or region
- App was cloned from another enterprise app template with a different ACS URL

---

## Failure Mode 2 — Missing Role Attribute (No Valid Role)

### Error signature
```
Your request included an invalid SAML response.
To use SAML, enable one or more IAM roles for this application.
```
The AWS console login page shows this error. Entra authentication succeeded.

### SAML Tracer diagnosis
1. Capture the assertion
2. In the SAML tab, search for: `https://aws.amazon.com/SAML/Attributes/Role`
3. If this attribute is absent from the assertion — confirmed root cause
4. Also check the `RoleSessionName` attribute at: `https://aws.amazon.com/SAML/Attributes/RoleSessionName`

### Fix
1. Entra ID portal → Enterprise App → Single Sign-On → Attributes & Claims → Edit
2. Verify the Role claim exists with the name: `https://aws.amazon.com/SAML/Attributes/Role`
3. Verify the value matches exactly: `RoleARN,IdPARN` (both ARNs, comma-separated, Role first)
```
arn:aws:iam::ACCOUNT_ID:role/IDSentinel-EntraFed-ReadOnly,arn:aws:iam::ACCOUNT_ID:saml-provider/IDSentinel-EntraIdP
```
4. If the attribute is missing, add it. If the value is wrong, correct both ARNs.
5. Save and retry login — SAML Tracer should now show the Role attribute in the assertion

**Target resolution time:** 5 minutes

### Why this happens in production
- Initial attribute mapping was never completed
- An admin deleted the claim while editing other attributes
- The role or IdP was renamed/recreated and the ARNs were not updated
- Account ID in the ARN was wrong (typo during setup)

---

## Failure Mode 3 — Expired or Mismatched Signing Certificate

### Error signature
```
Response signature invalid (Service provider metadata update required)
```
Or a variation: `The SAML response signature is invalid.`
The AWS error appears after the assertion is posted — Entra auth succeeded.

### SAML Tracer diagnosis
1. Capture the assertion
2. In the SAML tab, find the `<ds:X509Certificate>` value inside the `<Signature>` element
3. This is the certificate Entra used to sign the assertion
4. In AWS IAM → Identity Providers → `IDSentinel-EntraIdP`, download the metadata
5. Find the `<ds:X509Certificate>` value in the AWS metadata
6. Compare the two certificate values — a mismatch confirms the root cause

### Fix
1. In Entra ID portal → Enterprise App → Single Sign-On → SAML Signing Certificate
2. Confirm which certificate is marked **Active** — note the thumbprint
3. Click **Download → Federation Metadata XML** (this contains the active cert)
4. In AWS IAM → Identity Providers → `IDSentinel-EntraIdP` → Edit
5. Upload the new Federation Metadata XML
6. Save and retry login

**Target resolution time:** 7 minutes

### Why this happens in production
- Entra certificate was rotated (default 3-year expiry) and the SP metadata was never updated
- A new certificate was activated in Entra without notifying SP owners
- The wrong metadata file was uploaded to AWS during initial setup

### Prevention
- Set a recurring calendar reminder 30 days before the Entra SAML certificate expiry date
- Maintain a list of all SAML SPs that must receive updated metadata when the Entra cert rotates
- After every Entra cert rotation: update metadata in all SPs before activating the new cert

---

## Quick Reference — SAML Assertion Fields to Always Check

| Field | Where to Find It | What to Verify |
|-------|-----------------|----------------|
| `Destination` | Root `<Response>` element | Must be `https://signin.aws.amazon.com/saml` |
| `Issuer` | Inside `<Assertion>` | Must match Entra's Entity ID |
| `NameID` | `<Subject>` element | Should be the user's UPN |
| `Role` attribute | `<AttributeStatement>` | Must contain `RoleARN,IdPARN` |
| `RoleSessionName` attribute | `<AttributeStatement>` | Should contain the user's UPN or email |
| `<ds:X509Certificate>` | Inside `<Signature>` | Must match the cert in AWS IdP metadata |
| `NotBefore` / `NotOnOrAfter` | `<Conditions>` element | Assertion must not be expired |

---

## Escalation Path

| Condition | Action |
|-----------|--------|
| All three checks above clear but login still fails | Check AWS CloudTrail for `AssumeRoleWithSAML` events — look for error codes |
| Error: `Issuer not recognized` | Entra Entity ID doesn't match the IdP registered in AWS — re-register the IdP |
| Error: `Account suspended` or `Organization SCP blocking` | AWS org-level Service Control Policy may be blocking `sts:AssumeRoleWithSAML` — escalate to AWS admin |
| Cannot access Entra portal to make changes | Use break-glass Entra admin account — follow break-glass runbook |

---

## Post-Incident Documentation

After every SAML incident, log the following:

```
Date/Time:
Reporter:
Error message observed:
Diagnosis tool used: SAML Tracer / AWS Console / validate-saml-federation.ps1
Root cause:
Fix applied:
Time to resolution:
Prevention action:
Evidence attached (screenshots):
```

File in: `evidence/` folder with naming convention `INC-SAML-YYYYMMDD.md`
