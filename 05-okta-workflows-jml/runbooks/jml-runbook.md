# JML Workflow Operational Runbook — Scenario 05

---

## Validating All Workflows Are Active

1. Okta Admin Console -> left nav -> **Workflow**
2. Flows tab -> confirm all three flows show **Flow is ON**:
   - `JML - Joiner - HR Portal Assignment`
   - `JML - Mover - HR to Security Transfer`
   - `JML - Leaver - Full Offboarding`
3. If any flow shows OFF, click to open and toggle ON

---

## Joiner Flow Validation

**Trigger group:** `GRP-WORKFLOWS-HRApps` (Okta-native — not AD-synced)

**Important:** Do NOT use `GRP-ACCESS-HRApps` to test this flow.
That group is AD-synced and group changes do not fire Okta Workflow
events. Only additions to `GRP-WORKFLOWS-HRApps` trigger the Joiner flow.

**Steps:**
1. Confirm the test user does NOT already have HR Portal assigned
2. Okta Admin -> Directory -> Groups -> `GRP-WORKFLOWS-HRApps`
   -> Members -> Add Members -> add the test user
3. Wait up to 30 seconds
4. Workflows -> JML - Joiner - HR Portal Assignment
   -> Execution History -> confirm Success
5. Okta Admin -> Directory -> People -> test user
   -> Applications tab -> confirm IDSentinel HR Portal listed

**Expected result:** HR Portal assigned, execution shows Success,
Compose card output visible in execution detail.

---

## Mover Flow Validation

**Trigger group:** `GRP-ACCESS-SecurityApps` (Okta-native — not AD-synced)

**Prerequisites:**
- Test user must have IDSentinel HR Portal assigned before triggering
- Test user must NOT already be in `GRP-ACCESS-SecurityApps`

**Steps:**
1. Confirm test user has HR Portal assigned (Applications tab)
2. Okta Admin -> Directory -> Groups -> `GRP-ACCESS-SecurityApps`
   -> Members -> Add Members -> add the test user
3. Wait up to 30 seconds
4. Workflows -> JML - Mover - HR to Security Transfer
   -> Execution History -> confirm Success
5. Okta Admin -> Directory -> People -> test user
   -> Applications tab -> confirm:
   - IDSentinel HR Portal: NOT listed
   - Security Tools: listed
6. Workflows -> Tables -> JML Mover Audit Log
   -> confirm new row with user login, HR Portal, Security Tools, timestamp

**Expected result:** App swap confirmed, audit log row written,
Compose output visible in execution detail.

---

## Leaver Flow Validation

**Trigger:** Any user deactivation — no group scope

**Important constraints:**
- The flow does NOT remove app assignments — Okta clears AppUser
  records as part of deactivation before the Workflow runs
- The flow does NOT suspend the user — suspension is not applicable
  to an already-deactivated account (Okta returns 400)
- The flow logs the deactivation event via Compose card

**Steps:**
1. Okta Admin -> Directory -> People -> select test user
2. Confirm user is in Active status
3. More Actions -> **Deactivate** -> Confirm
4. Workflows -> JML - Leaver - Full Offboarding
   -> Execution History -> confirm Success
5. Expand execution -> confirm Compose card output shows
   user login and offboarding confirmation text
6. Okta Admin -> Directory -> People -> filter Status: Deactivated
   -> find user -> Applications tab -> confirm empty

**Expected result:** Execution Success, Compose output populated,
Applications tab empty on deactivated user.

---

## Continue If Gate — Mover Flow

The Mover flow uses a Continue If card to scope execution to
`GRP-ACCESS-SecurityApps` only. If this gate is misconfigured,
the flow will fire on any group addition and incorrectly remove
HR Portal and assign Security Tools.

**To verify the gate is correct:**
1. Open JML - Mover - HR to Security Transfer -> Flow tab
2. Click Continue If card
3. Confirm:
   - value a: `Group > Display Name` from trigger output
   - comparison: `equal to`
   - value b: `GRP-ACCESS-SecurityApps`

**If gate is misconfigured:** Update value b to `GRP-ACCESS-SecurityApps`,
save, and re-test by adding a user to a non-Security group — flow
should NOT fire.

---

## Disabling a Workflow

1. Workflows -> Flows -> click the flow to open
2. Top right -> toggle **Flow is ON** -> switch to OFF
3. Confirm toggle shows **Flow is OFF**
4. Document reason and timestamp:
   - Who disabled it
   - Why it was disabled
   - When it should be re-enabled

**Note:** Disabling a flow does not affect users already provisioned.
It only prevents future trigger events from executing.

---

## Okta Workflows OAuth Connection

All three flows use the **Okta Workflows OAuth** connection. If a flow
shows "Connection error" or fails with an auth error:

1. Okta Admin -> Applications -> Applications -> **Okta Workflows OAuth**
2. Confirm the app is Active
3. Generate a new Client Secret if needed
4. Workflows -> Connections -> update the Okta connection with new secret

---

## Audit Log — JML Mover Audit Log Table

1. Workflows console -> **Tables** tab -> **JML Mover Audit Log**
2. Columns: rowId (auto), updated (auto), User Login,
   Previous App, New App, Timestamp
3. Each successful Mover flow execution writes one row
4. To export for SOC 2 evidence: use the Filter option to scope
   by date range, screenshot the table