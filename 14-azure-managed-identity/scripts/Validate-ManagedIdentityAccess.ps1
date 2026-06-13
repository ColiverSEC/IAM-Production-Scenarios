# =============================================================================
# Validate-ManagedIdentityAccess.ps1
# IDSentinel Solutions -- SCN-14 Azure Managed Identity
# Validates managed identity configuration: identity status, role assignment,
# and Key Vault RBAC mode. Run from the host PC with Az PowerShell.
# Note: Token acquisition and secret retrieval must be run from inside the VM.
# =============================================================================

param (
    [Parameter(Mandatory = $true)]
    [string]$VmName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName
)

 = "[PASS]"
 = "[FAIL]"
 = @()

Write-Host ""
Write-Host "SCN-14 -- Managed Identity Validation" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check 1 -- VM system-assigned managed identity status
Write-Host "Checking VM managed identity status..." -ForegroundColor Yellow
try {
     = Get-AzVM -Name  -ResourceGroupName  -ErrorAction Stop
     = .Identity.Type

    if ( -like "*SystemAssigned*") {
         = .Identity.PrincipalId
        Write-Host " VM system-assigned identity is enabled" -ForegroundColor Green
        Write-Host "     Principal ID : " -ForegroundColor Gray
         += [PSCustomObject]@{ Check = "System-Assigned Identity"; Result = "PASS"; Detail =  }
    }
    else {
        Write-Host " VM does not have system-assigned managed identity enabled" -ForegroundColor Red
         += [PSCustomObject]@{ Check = "System-Assigned Identity"; Result = "FAIL"; Detail = "Identity type: " }
    }
}
catch {
    Write-Host " Could not retrieve VM: " -ForegroundColor Red
     += [PSCustomObject]@{ Check = "System-Assigned Identity"; Result = "ERROR"; Detail = .Exception.Message }
}

Write-Host ""

# Check 2 -- Key Vault RBAC authorization model
Write-Host "Checking Key Vault authorization model..." -ForegroundColor Yellow
try {
     = Get-AzKeyVault -VaultName  -ResourceGroupName  -ErrorAction Stop

    if (.EnableRbacAuthorization -eq True) {
        Write-Host " Key Vault is using Azure RBAC authorization mode" -ForegroundColor Green
         += [PSCustomObject]@{ Check = "Key Vault RBAC Mode"; Result = "PASS"; Detail = "EnableRbacAuthorization = True" }
    }
    else {
        Write-Host " Key Vault is using legacy access policies, not RBAC" -ForegroundColor Red
         += [PSCustomObject]@{ Check = "Key Vault RBAC Mode"; Result = "FAIL"; Detail = "EnableRbacAuthorization = False" }
    }
}
catch {
    Write-Host " Could not retrieve Key Vault: " -ForegroundColor Red
     += [PSCustomObject]@{ Check = "Key Vault RBAC Mode"; Result = "ERROR"; Detail = .Exception.Message }
}

Write-Host ""

# Check 3 -- Role assignment exists for managed identity on Key Vault
Write-Host "Checking role assignment on Key Vault..." -ForegroundColor Yellow
try {
     = Get-AzKeyVault -VaultName  -ResourceGroupName  -ErrorAction Stop
      = Get-AzVM -Name  -ResourceGroupName  -ErrorAction Stop
     = .Identity.PrincipalId

     = Get-AzRoleAssignment 
        -ObjectId  
        -Scope .ResourceId 
        -RoleDefinitionName "Key Vault Secrets User" 
        -ErrorAction SilentlyContinue

    if () {
        Write-Host " Key Vault Secrets User role assigned to managed identity" -ForegroundColor Green
        Write-Host "     Assignment ID : " -ForegroundColor Gray
         += [PSCustomObject]@{ Check = "Role Assignment"; Result = "PASS"; Detail = .RoleAssignmentId }
    }
    else {
        Write-Host " No Key Vault Secrets User assignment found for managed identity" -ForegroundColor Red
         += [PSCustomObject]@{ Check = "Role Assignment"; Result = "FAIL"; Detail = "No assignment found for principal " }
    }
}
catch {
    Write-Host " Role assignment check failed: " -ForegroundColor Red
     += [PSCustomObject]@{ Check = "Role Assignment"; Result = "ERROR"; Detail = .Exception.Message }
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
 | Format-Table -AutoSize
Write-Host ""
Write-Host "NOTE: Token acquisition and secret retrieval must be validated" -ForegroundColor Yellow
Write-Host "by running Get-ManagedIdentityToken.ps1 from inside the VM." -ForegroundColor Yellow
