# SCN-15 SOC 2 Control Mapping

## CC6.1 -- Logical Access Controls
**Evidence:** App registration screenshot showing four scoped application permissions only.
Admin consent confirmation. No admin credential used in agent execution path.

## CC6.3 -- Access Removal
**Evidence:** Decommission sequence -- secret deletion screenshot, 401 confirmation screenshot,
disabled app registration state screenshot.

## CC6.6 -- Logical Access Boundaries
**Evidence:** JWT decoded claims screenshot showing roles array scoped to four permissions only.
No delegated permissions. No user-context escalation path.

## CC6.8 -- Unauthorized Access Prevention
**Evidence:** 401 response on post-revocation token attempt. Entra sign-in log showing final
failed authentication event with error code invalid_client.
