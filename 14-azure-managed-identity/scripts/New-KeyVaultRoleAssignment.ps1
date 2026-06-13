# =============================================================================
# New-KeyVaultRoleAssignment.ps1
# IDSentinel Solutions -- SCN-14 Azure Managed Identity
# Assigns the Key Vault Secrets User role to the VM managed identity principal.
# Run from the host PC with Az PowerShell module (Install-Module Az).
# =============================================================================

param (
    [Parameter(Mandatory = $true)]
    [string]$ManagedIdentityObjectId,

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [string]$SubscriptionId = ""
)

# Key Vault Secrets User built-in role definition ID (constant across all tenants)
 = "4633458b-17de-408a-b874-0445c86b69e6"

Write-Host ""
Write-Host "SCN-14 -- Key Vault Role Assignment" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Connect to Azure if not already connected
 = Get-AzContext
if (-not ) {
    Write-Host "No active Azure session. Connecting..." -ForegroundColor Yellow
    Connect-AzAccount
}

Write-Host "Subscription : " -ForegroundColor Gray
Write-Host "Principal ID : " -ForegroundColor Gray
Write-Host "Key Vault    : " -ForegroundColor Gray
Write-Host "Role         : Key Vault Secrets User" -ForegroundColor Gray
Write-Host ""

# Get Key Vault resource ID for scoping the role assignment
try {
     = Get-AzKeyVault -VaultName  -ResourceGroupName  -ErrorAction Stop
     = .ResourceId
    Write-Host "Key Vault resource ID: " -ForegroundColor Gray
}
catch {
    Write-Host "ERROR: Could not retrieve Key Vault ''." -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    exit 1
}

# Assign the role
Write-Host ""
Write-Host "Assigning Key Vault Secrets User role..." -ForegroundColor Yellow

try {
     = New-AzRoleAssignment 
        -ObjectId  
        -RoleDefinitionId  
        -Scope  
        -ErrorAction Stop

    Write-Host ""
    Write-Host "SUCCESS -- Role assignment created" -ForegroundColor Green
    Write-Host "Assignment ID  : " -ForegroundColor Gray
    Write-Host "Principal      : " -ForegroundColor Gray
    Write-Host "Role           : " -ForegroundColor Gray
    Write-Host "Scope          : " -ForegroundColor Gray
    Write-Host ""
    Write-Host "NOTE: Role assignment propagation typically takes 1-2 minutes." -ForegroundColor Yellow
    Write-Host "Wait before running Get-ManagedIdentityToken.ps1 on the VM." -ForegroundColor Yellow
}
catch {
    if (.Exception.Message -like "*already exists*") {
        Write-Host "Role assignment already exists for this principal." -ForegroundColor Yellow
    }
    else {
        Write-Host "ERROR: Role assignment failed." -ForegroundColor Red
        Write-Host "" -ForegroundColor Red
        exit 1
    }
}
