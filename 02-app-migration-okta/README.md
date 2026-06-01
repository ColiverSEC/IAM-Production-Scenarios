# Scenario 02 — App Migration: Legacy IdP → Okta

## 🏢 Business Problem

IDSentinel Solutions completed the acquisition of a subsidiary operating on
a separate Microsoft Entra ID tenant. The subsidiary's workforce authenticated
to all SaaS applications through Entra ID as the sole SSO provider. The M&A
integration mandate required consolidating the subsidiary's application
portfolio onto Okta — IDSentinel's enterprise IdP — within 60 days to
eliminate dual-IdP sprawl, enforce consistent access policy, and reduce
licensing overhead.

A secondary blocker complicated the migration: the Okta AD Agent provisioning
wizard encountered an unresolved bug on the initial trial organization. Rather
than architect a workaround through an alternate provisioning path, the IAM
team resolved the blocker directly — provisioning a clean Integrator Free Plan
organization and deploying the AD Agent successfully against it. Users provision
from AD directly into Okta in a single hop, with no intermediary dependency.

The IAM team was tasked with:
1. Provisioning subsidiary users from AD into Okta via the Okta AD Agent
2. Migrating the subsidiary's primary SaaS application off Entra SSO onto Okta
3. Validating end-to-end SSO with SAML assertion capture using SAML Tracer
4. Executing a controlled cutover and disabling the legacy IdP configuration

---

## ⚠️ Risk

- Dual-IdP operation after acquisition creates inconsistent MFA enforcement
  and policy gaps — subsidiary users not governed by IDSentinel CA policies
- App migration without a validated rollback plan risks SSO outage for the
  acquired workforce
- No centralized audit trail — sign-in logs split across two IdP tenants
- Manual provisioning workarounds introduce orphaned account risk during
  the migration window
- Non-compliant with IDSentinel's Zero Trust mandate — all access must route
  through Okta for consistent policy enforcement
- SOC 2 Type II exposure under CC6.1 (Logical Access Controls) and CC6.3
  (Access Authorization)

---

## 🎯 Scope

| Parameter | Detail |
|-----------|--------|
| Legacy IdP | Microsoft Entra ID (M365 Developer Tenant) |
| Target IdP | Okta (Integrator Free Plan) |
| Provisioning path | AD → Okta AD Agent (direct) |
| Application migrated | IDSentinel HR Portal (SAML 2.0 — simulated via samlsp.com) |
| Users in scope | GRP-ACCESS-HRApps (synced from AD via Okta AD Agent) |
| Protocol | SAML 2.0 |
| Compliance target | SOC 2 Type II — CC6.1, CC6.3 |

---

## 🔧 Solution Design

The migration was executed across five workstreams:

**Workstream 1 — AD → Okta Directory Integration (AD Agent)**
The Okta AD Agent was deployed on IDS-DC and configured to sync directly
from on-prem Active Directory. OU scope was limited to the HR, IT, and
Security user OUs and the Groups OU. Attribute mappings were configured to
preserve UPN, display name, department, title, and manager hierarchy (via
managerDn). A full import was executed and 9 pilot users selectively
confirmed active — all others remained in pending state and did not count
against the Integrator Free Plan 10-user limit.

**Workstream 2 — Legacy IdP Baseline Documentation**
The HR Portal SAML integration in Entra ID was documented in full before
any migration activity — SP entity ID, ACS URL, NameID format, and
attribute mapping captured as the rollback target and migration spec.
SP-initiated SSO was tested against Entra to establish a verified
pre-migration baseline.

**Workstream 3 — SAML App Migration to Okta**
The HR Portal was re-registered in Okta as a custom SAML 2.0 application
using the Entra baseline as the configuration spec. Attribute statements
were mapped to deliver firstName, lastName, email, and department claims.
Access was assigned via GRP-ACCESS-HRApps — no individual user assignments.
samlsp.com was then updated with Okta's IdP metadata, redirecting all
authentication to Okta. This was the technical cutover point at the SP.

**Workstream 4 — SAML Tracer Validation**
SP-initiated and IdP-initiated login flows were both validated. SAML Tracer
was used to capture and inspect the full assertion against nine checks
covering issuer, destination, NameID format and value, all four attribute
statements, and signature validity. Three intentional break/fix scenarios
were then reproduced and resolved before cutover to validate the
troubleshooting runbook under realistic failure conditions.

**Workstream 5 — Cutover and Legacy IdP Decommission**
A pre-cutover checklist was executed to confirm all migration criteria
before touching the legacy configuration. The Entra SSO configuration was
set to Disabled — not deleted — preserving the rollback path for 30 days
per change management policy. Post-cutover SSO was re-validated with SAML
Tracer to confirm Okta as the sole issuer.

![App Migration Architecture](./diagrams/app-migration-architecture.png)

---

## 🛠️ Implementation

### Workstream 1 — AD Agent and User Provisioning

#### Step 1 — AD Agent Confirmed Active / Attribute Mappings Verified

AD Agent confirmed Active on IDS-DC. Attribute mappings in the To Okta tab
verified — key mappings include managerDn → manager (Create and update),
department, title, and email. Full import executed against scoped OUs;
9 pilot users selectively confirmed active.

![AD Agent Active](./screenshots/01-directory-integration/01-ad-agent-active.png)

---

![Attribute Mappings Verified](./screenshots/01-directory-integration/02-attribute-mapping.png)

---

![OU Import Scope](./screenshots/01-directory-integration/03-import-scope.png)

---

![Users Confirmed Active](./screenshots/01-directory-integration/04a-users-confirmed-active.png)

---

![Users Confirmed Active](./screenshots/01-directory-integration/04b-users-confirmed-active.png)

---

![Users Confirmed Active](./screenshots/01-directory-integration/04c-users-confirmed-active.png)

---

### Workstream 2 — Legacy IdP Baseline

#### Step 2 — Entra Legacy SAML Configuration Documented

IDSentinel HR Portal created in Entra as a custom enterprise application.
SAML SSO configured using samlsp.com as the SP — entity ID and ACS URL
entered, NameID set to EmailAddress. Configuration captured as the
pre-migration baseline and rollback target.

| Parameter | Legacy Entra Value |
|-----------|-------------------|
| IdP Entity ID | `https://sts.windows.net/{tenant-id}/` |
| IdP SSO URL | `https://login.microsoftonline.com/{tenant-id}/saml2` |
| SP Entity ID | `https://samlsp.com` |
| ACS URL | `https://samlsp.com/?acs` |
| NameID Format | `urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress` |
| NameID Value | `user.userprincipalname` |

![Entra Legacy SAML Configuration](./screenshots/02-legacy-baseline/05-entra-legacy-saml-config.png)

#### Step 3 — Pre-Migration SSO Baseline Validated

SP-initiated login tested via samlsp.com against the Entra configuration.
Successful SAML assertion receipt confirmed — this is the documented
"before" state proving the legacy IdP was functional prior to migration.

![Legacy SSO Validated - Pre-Migration](./screenshots/02-legacy-baseline/06-legacy-sso-validated.png)

---

### Workstream 3 — SAML App Migration to Okta

#### Step 4 — HR Portal Registered in Okta as Custom SAML 2.0 App

IDSentinel HR Portal created in Okta using the Entra baseline values as
the configuration spec. ACS URL, Audience URI, NameID format (EmailAddress),
and application username (Email) all configured from the documented baseline.

| Parameter | Value |
|-----------|-------|
| Single Sign-On URL (ACS) | `https://samlsp.com/?acs` |
| Audience URI (SP Entity ID) | `https://samlsp.com` |
| Name ID Format | `EmailAddress` |
| Name ID Value | `user.email` |

![Okta SAML App Created](./screenshots/03-okta-app-registration/07-okta-app-created.png)

---

![Okta SAML Settings](./screenshots/03-okta-app-registration/08-okta-saml-settings.png)

#### Step 5 — Attribute Statements Configured

Four attribute statements mapped to deliver the claims required downstream.
Department included specifically to support role-based authorization at the
SP — its absence would cause silent access failures without an auth error.

| Attribute | Value |
|-----------|-------|
| `firstName` | `user.firstName` |
| `lastName` | `user.lastName` |
| `email` | `user.email` |
| `department` | `user.department` |

![Attribute Statements](./screenshots/03-okta-app-registration/09-attribute-statements.png)

#### Step 6 — GRP-ACCESS-HRApps Assigned to App

Group assigned to the app in Okta — no individual user assignments.
All access lifecycle events governed entirely by group membership.

![Group Assignment](./screenshots/03-okta-app-registration/10-group-assignment.png)

#### Step 7 — SP Updated to Trust Okta (Technical Cutover Point)

Okta IdP metadata downloaded from the app's Sign On tab. samlsp.com
updated with Okta's metadata — SP now trusts Okta's signing certificate
and routes all authentication to the Okta SSO URL. Entra is no longer
in the authentication path at the SP layer.

| Parameter | Okta Value |
|-----------|------------|
| IdP Entity ID | `http://www.okta.com/{okta-app-id}` |
| IdP SSO URL | `https://{okta-domain}/app/idsentinel_hrportal/{app-id}/sso/saml` |
| Signing Certificate | Embedded in metadata XML |

![Okta Metadata Downloaded](./screenshots/03-okta-app-registration/11-okta-metadata-downloaded.png)

---

![SP Updated to Trust Okta](./screenshots/03-okta-app-registration/12-sp-metadata-updated.png)

---

### Workstream 4 — SAML Tracer Validation

#### Step 8 — SP-Initiated and IdP-Initiated Login Validated

SP-initiated login tested from samlsp.com — browser redirected to Okta,
authentication succeeded, assertion decoded by samlsp.com. IdP-initiated
login tested from the Okta end-user dashboard HR Portal tile — Okta posted
an unsolicited assertion directly to the ACS URL. Both flows confirmed.

![SP-Initiated Login](./screenshots/04-saml-validation/13-sp-initiated-login.png)

---

![IdP-Initiated Login](./screenshots/04-saml-validation/15a-idp-initiated-login.png)

---

![IdP-Initiated Login](./screenshots/04-saml-validation/15b-idp-initiated-login.png)

#### Step 9 — SAML Assertion Inspected via SAML Tracer (9/9 Checks)

SAML Tracer captured the POST to the ACS URL. Decoded assertion
validated against all nine checks:

| Check | Expected | Result |
|-------|----------|--------|
| Issuer = Okta Entity ID | `http://www.okta.com/{id}` | ✅ Pass |
| ACS URL correct | `https://samlsp.com/?acs` | ✅ Pass |
| NameID Format = EmailAddress | `emailAddress` | ✅ Pass |
| NameID Value = user email | `user@domain.com` | ✅ Pass |
| `firstName` attribute present | value delivered | ✅ Pass |
| `lastName` attribute present | value delivered | ✅ Pass |
| `email` attribute present | value delivered | ✅ Pass |
| `department` attribute present | value delivered | ✅ Pass |
| Signature valid | signed by Okta cert | ✅ Pass |

![SAML Tracer Assertion](./screenshots/04-saml-validation/14a-saml-tracer-assertion.png)

---

![SAML Tracer Assertion](./screenshots/04-saml-validation/14b-saml-tracer-assertion.png)

#### Step 10 — Break/Fix Scenarios Executed Pre-Cutover

Three intentional failure modes reproduced and resolved before cutover
to validate the troubleshooting runbook and build diagnostic muscle memory:

**Break/Fix #1 — Wrong ACS URL:** Trailing slash added to ACS URL in Okta.
SP reported destination mismatch. SAML Tracer confirmed the incorrect URL
in the assertion `Destination` attribute. Trailing slash removed — resolved.

**Break/Fix #2 — Missing Attribute:** `department` attribute statement
removed from Okta. SSO succeeded but samlsp.com showed no department claim
in the decoded assertion — demonstrating that missing attributes cause silent
downstream authorization failures, not authentication errors.
Attribute re-added — resolved.

**Break/Fix #3 — Wrong NameID Format:** NameID format changed from
`EmailAddress` to `Unspecified`. SP rejected the assertion with a format
mismatch error. SAML Tracer confirmed the wrong format in the NameID element.
Format restored to EmailAddress — resolved.

![Break/Fix ACS URL](./screenshots/04-saml-validation/16-breakfix-acs-url.png)

---

![Break/Fix Missing Attribute](./screenshots/04-saml-validation/17-breakfix-missing-attribute.png)

---

![Break/Fix NameID Format](./screenshots/04-saml-validation/18-breakfix-nameid.png)

---

### Workstream 5 — Cutover and Legacy IdP Decommission

#### Step 11 — Pre-Cutover Checklist Executed

Pre-cutover checklist script run against all migration criteria — AD Agent
health, user provisioning, SAML app configuration, SP metadata update,
both login flows, all assertion checks, and rollback readiness. All checks
passed before the legacy configuration was touched.

![Pre-Cutover Checklist](./screenshots/05-cutover/19-pre-cutover-checklist.png)

#### Step 12 — Legacy Entra SSO Disabled

Enterprise app SSO in Entra ID set to Disabled — not deleted. Configuration
preserved for 30 days as the rollback target per change management policy.

![Legacy Entra SSO Disabled](./screenshots/05-cutover/20-legacy-sso-disabled.png)

#### Step 13 — Post-Cutover Validation

Full login cycle re-run post-cutover. SP-initiated and IdP-initiated flows
both confirmed. SAML Tracer assertion captured as go-live evidence —
issuer is Okta. Entra is no longer in the authentication path.

![Post-Cutover Validated](./screenshots/05-cutover/21a-post-cutover-validated.png)

---

![Post-Cutover Validated](./screenshots/05-cutover/21b-post-cutover-validated.png)

---

![Post-Cutover Validated](./screenshots/05-cutover/21c-post-cutover-validated.png)

---

## ✅ Outcome

- AD Agent deployed on IDS-DC and registered successfully on Integrator
  Free Plan org — provisioning bug on trial org resolved at source, not
  worked around
- 9 pilot users provisioned from AD into Okta with full attribute fidelity —
  department, title, and manager hierarchy all populated
- IDSentinel HR Portal migrated from Entra SSO to Okta SAML 2.0
- 9/9 SAML assertion checks passed via SAML Tracer
- SP-initiated and IdP-initiated login flows both validated
- 3 break/fix scenarios reproduced and resolved pre-cutover
- Legacy Entra SSO disabled post-cutover — rollback window preserved for 30 days
- SOC 2 evidence package produced

## 📊 Migration Results

| Metric | Result |
|--------|--------|
| Users provisioned AD → Okta | 9 (GRP-ACCESS-HRApps) |
| SAML assertion checks passed | 9 / 9 |
| SP-initiated SSO validated | ✅ Yes |
| IdP-initiated SSO validated | ✅ Yes |
| Break/fix scenarios resolved | 3 / 3 |
| Legacy IdP SSO configuration | Disabled — rollback preserved |
| Rollback procedure documented | ✅ Yes |
| SOC 2 evidence package produced | ✅ Yes |

---

## 📁 Files

| File | Description |
|------|-------------|
| `scripts/pre-cutover-checklist.ps1` | Validates all migration criteria before go-live |
| `scripts/validate-saml-groups.ps1` | Confirms group membership sync from AD to Okta |
| `runbooks/app-migration-cutover-runbook.md` | Step-by-step cutover SOP with rollback procedure |
| `diagrams/app-migration-architecture.png` | Migration architecture — Entra legacy IdP → Okta target IdP |
| `screenshots/` | Implementation evidence organized by workstream |
| `evidence/` | SOC 2 audit artifacts and script outputs |
| `evidence/pre-cutover-results-{date}.csv` | Pre-cutover checklist output — all checks passed before cutover |

---

## 🛡️ SOC 2 Mapping

| Control | Evidence |
|---------|----------|
| CC6.1 — Logical Access Controls | SAML Tracer assertion capture — NameID, attributes, and signature validated; Okta is the sole trusted IdP post-cutover |
| CC6.3 — Access Authorization | Group-based assignment in Okta — GRP-ACCESS-HRApps governs all access; no individual user assignments; pre-cutover checklist documents authorization state |

---

## 🔗 References

- [Okta: Active Directory Integration Overview](https://help.okta.com/en-us/content/topics/directory/ad-agent-main.htm)
- [Okta: Configure Active Directory Attribute Mappings](https://help.okta.com/en-us/content/topics/directory/ad-attribute-mapping.htm)
- [Okta: Create a Custom SAML App Integration](https://help.okta.com/en-us/content/topics/apps/apps_app_integration_wizard_saml.htm)
- [Okta: SAML Attribute Statements](https://help.okta.com/en-us/content/topics/apps/apps_attribute_mapping.htm)
- [samlsp.com — Free SAML SP Testing Tool](https://samlsp.com/en/)
- [SAML Tracer Chrome Extension](https://chromewebstore.google.com/detail/saml-tracer/mpdajninpobndbfcldcmbpnnbhibjmch)
- [Okta: Troubleshoot SAML](https://help.okta.com/en-us/content/topics/apps/apps_error_codes.htm)