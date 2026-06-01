# Scenario 14 — Securing Non-Human Identities: Azure Managed Identity

## 🏢 Business Problem

IDSentinel Solutions' Azure workloads required a standardized, auditable
method for applications and services to authenticate to other Azure resources
without using human credentials. An internal security review identified that
three risky credential patterns had emerged across the environment:

1. **AD service accounts with non-expiring passwords** — shared across
   multiple application teams, never rotated, no MFA, and impossible to
   attribute activity to a single workload
2. **Hardcoded API keys in application code** — secrets committed to
   repositories or embedded in deployment scripts, creating permanent
   exposure if the code was ever accessed by an unauthorized party
3. **App registrations with client secrets and no rotation** — secrets
   set to maximum expiry, no rotation schedule, and no process to revoke
   them if a developer left the organization

Each pattern violated IDSentinel's Zero Trust initiative and the core
principle that no standing credential should exist in the environment
longer than its operational need.

The Security team mandated that all non-human identities operating in
Azure follow the same governance framework applied to human identities:
least privilege, no standing credentials, and a verifiable audit trail.

---

## ⚠️ Risk

### The Three Anti-Patterns This Scenario Replaces

| Pattern | Risk |
|---------|------|
| AD service account with non-expiring password | Permanent blast radius; credential theft grants standing access with no time limit |
| Hardcoded API key in application code | Secret exposed in any code review, repository clone, or log file — silent exfiltration |
| App registration secret with no rotation | Forgotten secrets with multi-year expiry become persistent backdoors; no process to revoke on developer offboarding |

### Compliance Exposure

- Non-compliant with IDSentinel's Zero Trust initiative (no standing credentials)
- Potential SOC 2 Type II CC6.1 (logical access) and CC6.6 (external threats) exposure
- No audit trail for non-human access to sensitive resources violates CC7.2

---

## 🎯 Scope

- **Identity type:** Non-human (workload) identity — Azure Virtual Machine
- **Credential pattern replaced:** AD service account / hardcoded API key
- **Azure services:** Virtual Machine, Managed Identity, Key Vault, RBAC, Diagnostic Settings, Log Analytics
- **Control implemented:** System-assigned managed identity with scoped RBAC, Key Vault secret retrieval from inside the VM with zero credentials in code, diagnostic logging to Log Analytics for audit evidence
- **Validation:** Secret retrieved from VM shell using IMDS token — no credentials stored on disk, in environment variables, or in code

---

## 🔧 Solution Design

### Human vs. Non-Human Identity — The Governing Framework

The same principles that govern human identities apply directly to non-human
identities. The implementation differs by platform; the philosophy does not.

| Control | Human Identity | Non-Human Identity (This Scenario) |
|---------|---------------|--------------------------------------|
| Authentication | MFA via Entra ID | Managed identity — Azure-attested, no credential issued |
| Authorization | Group-based RBAC, least privilege | Scoped RBAC role assignment — Key Vault Secrets User only |
| Credential lifetime | Session tokens, PIM time-bound activation | No credential exists — token issued per-request by IMDS |
| Audit trail | Entra sign-in logs | Key Vault diagnostic logs → Log Analytics |
| Rotation | Password policy / SSPR | Not applicable — no credential to rotate |

### Why Managed Identity Over the Three Anti-Patterns

A system-assigned managed identity is tied to the lifecycle of the Azure
resource it is assigned to. When the VM is deleted, the identity is deleted.
There is no credential to issue, rotate, store, or exfiltrate. The VM
authenticates to Azure AD using a hardware-backed attestation through the
Instance Metadata Service (IMDS) endpoint — an internal Azure service
unreachable from outside the VM. The resulting access token is short-lived
and scoped to the resource the identity has been granted access to.

This directly eliminates all three anti-patterns:
- No service account password — there is no password
- No API key in code — the IMDS call requires zero secrets
- No app registration secret — the identity is platform-managed

### Architecture

The solution was built across four workstreams:

**Workstream 1 — VM and Managed Identity**
Azure VM deployed with system-assigned managed identity enabled at creation.
The identity is Azure-managed, non-exportable, and tied to VM lifecycle.

**Workstream 2 — Key Vault and Secret**
Azure Key Vault provisioned with RBAC authorization model (not legacy access
policies). A test secret stored to represent a sensitive credential the
application requires — database connection string, API endpoint key, or
third-party service token.

**Workstream 3 — RBAC Assignment**
Managed identity granted the built-in `Key Vault Secrets User` role scoped
to the specific Key Vault. This is the narrowest role that permits secret
retrieval — it cannot list secrets, manage keys, modify certificates, or
alter vault configuration.

**Workstream 4 — Diagnostic Logging**
Key Vault diagnostic settings configured to forward `AuditEvent` logs to
a Log Analytics workspace. Every secret retrieval generates a log entry
recording the caller identity (the VM's managed identity object ID), the
operation, the result, and the timestamp — providing the audit evidence
chain required for compliance.

![Azure Managed Identity Architecture](./diagrams/managed-identity-architecture.png)

---

## 🛠️ Implementation

### Prerequisites
- Azure subscription with Contributor or Owner access
- Azure CLI installed and authenticated (`az login`)
- Resource group created for the scenario

---

### Step 1 — Deploy the Azure VM with System-Assigned Managed Identity

Create the VM with managed identity enabled at provisioning time. Enabling
it at creation rather than post-deployment is the recommended pattern —
avoids a separate identity assignment step and ensures the identity is active
before any application code runs.

```bash
az vm create \
  --resource-group rg-idsentinel-lab \
  --name vm-idsentinel-nhid \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --assign-identity '[system]' \
  --location eastus
```

![VM Deployed with Managed Identity](./screenshots/01-vm-managed-identity-enabled.png)

Verify the identity was assigned and capture the principal ID — this is the
object ID of the managed identity in Entra ID, used in the RBAC assignment.

```bash
az vm identity show \
  --resource-group rg-idsentinel-lab \
  --name vm-idsentinel-nhid
```

![VM Identity Principal ID](./screenshots/02-vm-identity-principal-id.png)

---

### Step 2 — Provision Key Vault with RBAC Authorization Model

Create the Key Vault with `--enable-rbac-authorization` flag. This activates
the RBAC model rather than legacy access policies — RBAC authorization is the
current recommended pattern and required for scoped role assignments.

```bash
az keyvault create \
  --name kv-idsentinel-nhid \
  --resource-group rg-idsentinel-lab \
  --location eastus \
  --enable-rbac-authorization true \
  --sku standard
```

Store the test secret that the VM application will retrieve. This represents
any sensitive credential the workload requires — a database connection string,
a third-party API key, or an internal service token.

```bash
az keyvault secret set \
  --vault-name kv-idsentinel-nhid \
  --name "db-connection-string" \
  --value "Server=sql-prod.idsentinel.local;Database=AppDB;Encrypt=True"
```

![Key Vault Created with Secret](./screenshots/03-keyvault-secret-created.png)

---

### Step 3 — Assign Key Vault Secrets User Role to the Managed Identity

Scope the RBAC assignment to the specific Key Vault resource. This enforces
least privilege — the managed identity can retrieve secrets from this vault
only, and cannot list secrets, manage keys, or access any other Key Vault
in the subscription.

```bash
# Capture the Key Vault resource ID
KV_ID=$(az keyvault show \
  --name kv-idsentinel-nhid \
  --resource-group rg-idsentinel-lab \
  --query id -o tsv)

# Capture the managed identity principal ID
PRINCIPAL_ID=$(az vm identity show \
  --resource-group rg-idsentinel-lab \
  --name vm-idsentinel-nhid \
  --query principalId -o tsv)

# Assign the built-in Key Vault Secrets User role
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --scope $KV_ID
```

![RBAC Assignment — Key Vault Secrets User](./screenshots/04-rbac-assignment-kv-secrets-user.png)

Verify the assignment is correctly scoped in the Azure portal — confirm
role name, assignee (managed identity), and scope (Key Vault resource, not
subscription or resource group).

![RBAC Assignment Verified in Portal](./screenshots/05-rbac-assignment-portal-verified.png)

---

### Step 4 — Retrieve Secret from Inside the VM with Zero Credentials in Code

SSH into the VM and retrieve the secret using only the IMDS endpoint.
This is the proof-of-concept step — the entire flow executes with no
API key, no client secret, no service account password, and no stored
credential of any kind.

```bash
ssh azureuser@<VM_PUBLIC_IP>
```

**Step 4a — Request an access token from the IMDS endpoint**

The Instance Metadata Service is an internal Azure endpoint available
only from within the VM at `169.254.169.254`. It issues a short-lived
access token scoped to the requested Azure resource — in this case,
Key Vault (`https://vault.azure.net`).

```bash
TOKEN=$(curl -s -H "Metadata:true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?\
api-version=2018-02-01&resource=https://vault.azure.net" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "Token acquired: ${TOKEN:0:50}..."
```

![IMDS Token Acquired](./screenshots/06-imds-token-acquired.png)

**Step 4b — Use the token to retrieve the secret from Key Vault**

```bash
SECRET=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://kv-idsentinel-nhid.vault.azure.net/secrets/db-connection-string?api-version=7.4" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])")

echo "Secret retrieved: $SECRET"
```

![Secret Retrieved — Zero Credentials in Code](./screenshots/07-secret-retrieved-zero-credentials.png)

The secret is retrieved and available to the application. No credential
appears in any script, environment variable, configuration file, or
repository. The token is ephemeral — it expires and cannot be reused
beyond its validity window.

---

### Step 5 — Enable Key Vault Diagnostic Logging

Create a Log Analytics workspace to receive the Key Vault audit events,
then configure Key Vault diagnostic settings to forward `AuditEvent` logs.
Every secret retrieval — including the one performed in Step 4 — will
generate a log entry that can be used as audit evidence.

```bash
# Create the Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group rg-idsentinel-lab \
  --workspace-name law-idsentinel-nhid \
  --location eastus

# Capture the workspace resource ID
LAW_ID=$(az monitor log-analytics workspace show \
  --resource-group rg-idsentinel-lab \
  --workspace-name law-idsentinel-nhid \
  --query id -o tsv)

# Capture the Key Vault resource ID
KV_ID=$(az keyvault show \
  --name kv-idsentinel-nhid \
  --resource-group rg-idsentinel-lab \
  --query id -o tsv)

# Enable diagnostic settings — AuditEvent category to Log Analytics
az monitor diagnostic-settings create \
  --name diag-kv-audit \
  --resource $KV_ID \
  --workspace $LAW_ID \
  --logs '[{"category":"AuditEvent","enabled":true}]'
```

![Diagnostic Settings Configured](./screenshots/08-diagnostic-settings-enabled.png)

---

### Step 6 — Validate Audit Event in Log Analytics

After a short ingestion delay (typically 5–15 minutes), query the
`AzureDiagnostics` table for the secret retrieval event. This log entry
is the audit evidence chain — it records the managed identity's object ID
as the caller, the operation, the result code, and the timestamp.

```kusto
AzureDiagnostics
| where ResourceType == "VAULTS"
| where OperationName == "SecretGet"
| where ResultType == "Success"
| project TimeGenerated, CallerIPAddress, identity_claim_oid_g,
          OperationName, ResultType, requestUri_s
| order by TimeGenerated desc
| take 10
```

![Audit Log — Secret Retrieval Captured](./screenshots/09-audit-log-secret-retrieval.png)

The `identity_claim_oid_g` field contains the managed identity's object ID —
the same principal ID captured in Step 1. This provides an unambiguous link
between the access event and the non-human identity that performed it,
equivalent to the audit trail a human identity would generate in Entra sign-in logs.

---

## 🔗 Cross-Cloud NHI Narrative — Scenario 09 + Scenario 14

These two scenarios together form a complete non-human identity architecture
story across the two dominant cloud platforms in enterprise environments.

| Dimension | AWS (Scenario 09) | Azure (Scenario 14) |
|-----------|-------------------|----------------------|
| Mechanism | IAM role assumption via STS | System-assigned managed identity via IMDS |
| Credential issued | Temporary access key + session token (15 min – 12 hr) | Short-lived OAuth2 access token (scoped to resource) |
| Bound to resource | IAM role ARN | VM resource lifecycle |
| Scoping control | Trust policy + permission boundary | RBAC scope (resource-level) |
| Confused deputy protection | ExternalId condition in trust policy | Identity bound to single resource — no delegation |
| Audit trail | CloudTrail AssumeRole events | Key Vault AuditEvent → Log Analytics |

Both platforms implement the same philosophy: the workload proves who it is
through a platform-attested mechanism, receives a short-lived token, and
accesses only the resource it has been explicitly authorized to reach. No
standing credential exists at any point in the flow.

---

## ✅ Outcome

- Azure VM deployed with system-assigned managed identity — zero credentials
  issued, stored, or required by the application
- Key Vault provisioned with RBAC authorization model; test secret stored
  representing a production workload credential requirement
- `Key Vault Secrets User` role assigned to managed identity scoped to the
  specific Key Vault resource — least-privilege enforcement confirmed;
  no list, write, or management permissions granted
- Secret retrieved from inside the VM using IMDS token with zero credentials
  in code — no API key, no service account password, no client secret
  present at any step of the retrieval flow
- Key Vault diagnostic logging enabled; `AuditEvent` category forwarding
  to Log Analytics; secret retrieval event captured with managed identity
  object ID as caller — verifiable audit trail for compliance evidence
- Three anti-patterns replaced: AD service account with non-expiring
  password, hardcoded API key in application code, app registration secret
  with no rotation schedule
- SOC 2 Type II CC6.1 (logical access controls) and CC7.2 (monitoring for
  unauthorized access) controls evidenced with audit log screenshot

---

## 📊 Control Coverage Summary

| Control | Implementation | Evidence |
|---------|---------------|----------|
| No standing credentials | Managed identity — no password, no secret issued | IMDS token flow — zero credentials in shell session |
| Least privilege | Key Vault Secrets User role — narrowest retrieval permission | RBAC assignment screenshot scoped to vault resource |
| Audit trail | Key Vault AuditEvent diagnostic logging | Log Analytics query — SecretGet event with identity OID |
| Lifecycle-bound identity | System-assigned identity tied to VM — deleted on VM removal | Azure portal identity tab — SystemAssigned status |
| Zero credential rotation burden | No credential exists to rotate | Architecture — token issued per-request, no persistence |

---

## 🎯 Interview Talking Point

> "I govern non-human identities the same way I govern human ones —
> least privilege, no standing credentials, and an audit trail. On Azure
> that means managed identity over service accounts. When a VM needs to
> pull a secret from Key Vault, there's no API key in the code, no
> service account password in a config file — the VM authenticates through
> IMDS, gets a short-lived token, and retrieves only what it's been
> explicitly authorized to access. The Key Vault diagnostic logs capture
> every retrieval event with the managed identity's object ID as the caller
> — same audit chain I'd expect for a human identity. On AWS the same
> philosophy applies through STS role assumption with ExternalId. Different
> platform, same governance framework."

---

## 📁 Files

| File | Description |
|------|-------------|
| `scripts/deploy.sh` | Full Azure CLI deployment — VM, Key Vault, RBAC, diagnostics |
| `scripts/retrieve-secret.sh` | IMDS token acquisition and Key Vault secret retrieval — run inside VM |
| `scripts/query-audit-log.kql` | KQL query for Log Analytics — SecretGet audit event |
| `diagrams/managed-identity-architecture.png` | End-to-end architecture diagram |
| `screenshots/` | Evidence of implementation at each stage |

---

## 🔗 References

- [Azure Managed Identities Overview](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)
- [Key Vault RBAC Authorization Model](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- [IMDS Token Acquisition](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token)
- [Key Vault Diagnostic Logging](https://learn.microsoft.com/en-us/azure/key-vault/general/howto-logging)
- [SOC 2 CC6.1 / CC6.6 Mapping](https://learn.microsoft.com/en-us/azure/compliance/offerings/offering-soc-2)