# =============================================================================
# deploy.ps1
# Description: Full Azure CLI deployment for Scenario 14.
#              Provisions VM with managed identity, Key Vault, RBAC assignment,
#              and diagnostic logging to Log Analytics.
#
# Usage:
#   1. az login
#   2. Confirm subscription: az account show
#   3. .\deploy.ps1
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 14 -- Securing Non-Human Identities: Azure Managed Identity
# =============================================================================

$ResourceGroup = "rg-idsentinel-lab"
$Location      = "eastus"
$VmName        = "vm-idsentinel-nhid"
$KvName        = "kv-idsentinel-nhid"
$LawName       = "law-idsentinel-nhid"
$AdminUser     = "azureuser"
$SecretName    = "db-connection-string"
$SecretValue   = "Server=sql-prod.idsentinel.local;Database=AppDB;Encrypt=True"

Write-Host ""
Write-Host "============================================================"
Write-Host "  Scenario 14 -- Azure Managed Identity Deployment"
Write-Host "============================================================"
Write-Host ""

# --- Step 1: Deploy VM with system-assigned managed identity ----------------
Write-Host "[Step 1] Deploying VM with system-assigned managed identity..."

az vm create `
  --resource-group $ResourceGroup `
  --name $VmName `
  --image Win2022Datacenter `
  --size Standard_B2s `
  --admin-username $AdminUser `
  --admin-password (Read-Host -Prompt "Enter VM admin password" -AsSecureString | `
      [System.Runtime.InteropServices.Marshal]::PtrToStringAuto( `
      [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_))) `
  --assign-identity "[system]" `
  --location $Location

$PrincipalId = az vm identity show `
  --resource-group $ResourceGroup `
  --name $VmName `
  --query principalId -o tsv

Write-Host "[+] VM deployed."
Write-Host "[+] Managed Identity Principal ID: $PrincipalId"

# --- Step 2: Provision Key Vault with RBAC authorization model --------------
Write-Host ""
Write-Host "[Step 2] Creating Key Vault..."

az keyvault create `
  --name $KvName `
  --resource-group $ResourceGroup `
  --location $Location `
  --enable-rbac-authorization true `
  --sku standard

Write-Host "[+] Storing test secret..."

az keyvault secret set `
  --vault-name $KvName `
  --name $SecretName `
  --value $SecretValue

Write-Host "[+] Key Vault and secret created."

# --- Step 3: Assign Key Vault Secrets User role to managed identity ---------
Write-Host ""
Write-Host "[Step 3] Assigning Key Vault Secrets User role..."

$KvId = az keyvault show `
  --name $KvName `
  --resource-group $ResourceGroup `
  --query id -o tsv

az role assignment create `
  --role "Key Vault Secrets User" `
  --assignee-object-id $PrincipalId `
  --assignee-principal-type ServicePrincipal `
  --scope $KvId

Write-Host "[+] RBAC assignment complete."
Write-Host "    Scope: $KvId"

# --- Step 4: Create Log Analytics workspace and enable diagnostics ----------
Write-Host ""
Write-Host "[Step 4] Creating Log Analytics workspace..."

az monitor log-analytics workspace create `
  --resource-group $ResourceGroup `
  --workspace-name $LawName `
  --location $Location

$LawId = az monitor log-analytics workspace show `
  --resource-group $ResourceGroup `
  --workspace-name $LawName `
  --query id -o tsv

Write-Host "[+] Enabling Key Vault diagnostic logging..."

az monitor diagnostic-settings create `
  --name "diag-kv-audit" `
  --resource $KvId `
  --workspace $LawId `
  --logs '[{"category":"AuditEvent","enabled":true}]'

Write-Host "[+] Diagnostic settings enabled."

# --- Summary ----------------------------------------------------------------
$VmIp = az vm list-ip-addresses `
  --resource-group $ResourceGroup `
  --name $VmName `
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv

Write-Host ""
Write-Host "============================================================"
Write-Host "  DEPLOYMENT COMPLETE"
Write-Host "============================================================"
Write-Host ""
Write-Host "  VM Name          : $VmName"
Write-Host "  Managed Identity : $PrincipalId"
Write-Host "  Key Vault        : $KvName"
Write-Host "  Secret Name      : $SecretName"
Write-Host "  Log Analytics    : $LawName"
Write-Host "  VM Public IP     : $VmIp"
Write-Host ""
Write-Host "  Next step: RDP into the VM, open VS Code, run Retrieve-Secret.ps1"
Write-Host "  mstsc /v:$VmIp"
