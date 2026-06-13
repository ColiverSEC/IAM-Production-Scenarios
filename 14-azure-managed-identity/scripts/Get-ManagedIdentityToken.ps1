# =============================================================================
# Get-ManagedIdentityToken.ps1
# IDSentinel Solutions -- SCN-14 Azure Managed Identity
# Acquires a bearer token from the IMDS endpoint and retrieves a Key Vault secret.
# Run this script from inside the Azure VM (Cloud Ops VM or IDS-DC).
# No credentials are stored in this script.
# =============================================================================

param (
    [Parameter(Mandatory = $true)]
    [string]$VaultName,

    [Parameter(Mandatory = $true)]
    [string]$SecretName
)

Write-Host ""
Write-Host "SCN-14 -- Managed Identity Token Acquisition" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1 -- Acquire bearer token from IMDS endpoint
# The IMDS endpoint is only reachable from inside the VM (169.254.169.254)
Write-Host "[1] Requesting token from IMDS endpoint..." -ForegroundColor Yellow

 = "http://169.254.169.254/metadata/identity/oauth2/token" +
           "?api-version=2018-02-01" +
           "&resource=https://vault.azure.net"

try {
     = Invoke-RestMethod 
        -Uri  
        -Headers @{ Metadata = "true" } 
        -Method Get 
        -ErrorAction Stop

     = .access_token
     = [System.DateTimeOffset]::FromUnixTimeSeconds(.expires_on)

    Write-Host "    Token acquired successfully" -ForegroundColor Green
    Write-Host "    Token type : " -ForegroundColor Gray
    Write-Host "    Expires on : " -ForegroundColor Gray
    Write-Host "    Resource   : " -ForegroundColor Gray
}
catch {
    Write-Host "    FAILED to acquire token from IMDS." -ForegroundColor Red
    Write-Host "    Error: " -ForegroundColor Red
    Write-Host ""
    Write-Host "    Verify that system-assigned managed identity is enabled on this VM." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 2 -- Call Key Vault REST API using the bearer token
Write-Host "[2] Retrieving secret from Key Vault..." -ForegroundColor Yellow
Write-Host "    Vault  : " -ForegroundColor Gray
Write-Host "    Secret : " -ForegroundColor Gray

 = "https://.vault.azure.net/secrets/" +
         "?api-version=7.4"

try {
     = Invoke-RestMethod 
        -Uri  
        -Headers @{ Authorization = "Bearer " } 
        -Method Get 
        -ErrorAction Stop

    Write-Host ""
    Write-Host "    SUCCESS -- Secret retrieved with no stored credentials" -ForegroundColor Green
    Write-Host "    Secret name    : " -ForegroundColor Gray
    Write-Host "    Secret version : " -ForegroundColor Gray
    Write-Host "    Content type   : " -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Value (first 4 chars): ****" -ForegroundColor Green
}
catch {
     = .Exception.Response.StatusCode.value__
    Write-Host ""
    Write-Host "    FAILED to retrieve secret -- HTTP " -ForegroundColor Red
    Write-Host "    Error: " -ForegroundColor Red
    Write-Host ""

    if ( -eq 403) {
        Write-Host "    HTTP 403: The managed identity is authenticated but not authorized." -ForegroundColor Yellow
        Write-Host "    Assign the 'Key Vault Secrets User' role to the managed identity" -ForegroundColor Yellow
        Write-Host "    principal on the Key Vault Access Control (IAM) blade." -ForegroundColor Yellow
    }
    elseif ( -eq 404) {
        Write-Host "    HTTP 404: Secret not found. Verify the secret name and vault name." -ForegroundColor Yellow
    }
    exit 1
}

Write-Host ""
Write-Host "Validation complete. No credentials were used in this script." -ForegroundColor Cyan
