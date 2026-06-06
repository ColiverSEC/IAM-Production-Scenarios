# SOC 2 Control Mapping — Scenario 05

---

## CC6.2 — Logical Access Provisioning

**Control statement:** The entity implements logical access security
measures to protect against threats from sources outside its system
boundaries. Access is provisioned based on authorized roles.

| Evidence | Screenshot | What It Proves |
|---|---|---|
| Joiner Flow canvas | 05-01-joiner-flow-canvas.png | Provisioning is automated and tied to group membership — no manual admin action required |
| Joiner execution log | 05-02-joiner-flow-execution-log.png | Timestamped proof that HR Portal was assigned automatically on group addition |
| User Applications tab post-trigger | 05-03-joiner-app-assignment-confirmed.png | HR Portal visible on user profile — assignment confirmed at the user level |
| Mover Flow canvas | 05-04-mover-flow-canvas.png | Role change removes previous access and grants new access in a single automated event |
| Mover execution log | 05-05-mover-flow-execution-log.png | Timestamped proof of app swap — no manual intervention |
| JML Mover Audit Log table | 05-07-mover-audit-log-table.png | Persistent audit record of role change with user, previous app, new app, and timestamp |

---

## CC6.3 — Access Removal on Offboarding and Role Change

**Control statement:** The entity removes access when it is no longer
required, including on termination or role change.

| Evidence | Screenshot | What It Proves |
|---|---|---|
| Mover Flow canvas | 05-04-mover-flow-canvas.png | HR Portal access removed automatically on Security group addition — no residual access from prior role |
| User Applications tab post-mover | 05-06-mover-app-swap-confirmed.png | HR Portal absent from user profile after role transfer |
| Leaver Flow canvas | 05-08-leaver-flow-canvas.png | Deactivation event triggers automated offboarding flow |
| Leaver execution log | 05-09-leaver-flow-execution-log.png | Timestamped proof that offboarding flow executed on deactivation |
| Deactivated user Applications tab | 05-10-leaver-zero-app-assignments.png | No active app assignments on deactivated account |

---

## Production Constraint Note

During implementation, the Leaver flow's explicit app removal cards
returned 404 because Okta clears AppUser records as part of the
deactivation event. This is documented as a production-relevant
finding: in Okta's lifecycle model, deactivation is the terminal
access removal event. A deactivated account cannot authenticate
regardless of residual group membership records in the directory.

This finding supports CC6.3 compliance — the control requires that
access is removed, not that it is removed via a specific mechanism.
Deactivation achieves the control objective.

---

## Break/Fix Evidence — Gate Misconfiguration

| Evidence | Screenshot | What It Proves |
|---|---|---|
| Incorrect assignment (gate removed) | 05-12-breakfix-incorrect-assignment.png | Without the Continue If gate, the Mover flow fires on any group addition — violating CC6.2 by granting incorrect access |
| Corrected flow canvas | 05-13-breakfix-corrected-flow-canvas.png | Continue If gate restored — flow scoped to correct group |
| Validation — flow did not fire | 05-14-breakfix-corrected-execution-log.png | Gate confirmed working — no execution on non-Security group addition |