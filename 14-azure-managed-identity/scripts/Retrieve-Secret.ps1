# =============================================================================
# Retrieve-Secret.ps1
# Description: Retrieves a Key Vault secret from inside the Windows VM using
#              the IMDS endpoint and PowerShell Invoke-WebRequest.
#              No credentials required at any step.
#
# Run this INSIDE the VM:
#   RDP into the VM -> open VS Code -> open terminal -> .\scripts\Retrieve-Secret.ps1
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 14 -- Securing Non-Human Identities: Azure Managed Identity
# =============================================================================

$KvName     = "kv-idsentinel-nhid"
$SecretName = "db-connection-string"
$ApiVersion = "7.4"

Write-Host ""
Write-Host "============================================================"
Write-Host "  Scenario 14 -- IMDS Token + Key Vault Secret Retrieval"
Write-Host "  Zero credentials in code demonstration"
Write-Host "============================================================"
Write-Host ""

# --- Step 1: Request access token from IMDS ---------------------------------
Write-Host "[Step 1] Requesting access token from IMDS endpoint..."
Write-Host "         Endpoint : http://169.254.169.254/metadata/identity/oauth2/token"
Write-Host "         Resource : https://vault.azure.net"
Write-Host ""

$ImdsUri = "http://169.254.169.254/metadata/identity/oauth2/token" +
           "?api-version=2018-02-01&resource=https://vault.azure.net"

$TokenResponse = Invoke-WebRequest -Uri $ImdsUri `
    -Headers @{ Metadata = "true" } `
    -UseBasicParsing

$Token = ($TokenResponse.Content | ConvertFrom-Json).access_token

if (-not $Token) {
    Write-Host "[!] Failed to acquire token. Verify the managed identity is assigned to this VM."
    exit 1
}

Write-Host "[+] Token acquired (first 60 chars): $($Token.Substring(0,60))..."
Write-Host ""

# --- Step 2: Retrieve secret from Key Vault ---------------------------------
Write-Host "[Step 2] Retrieving secret from Key Vault..."
Write-Host "         Vault  : $KvName"
Write-Host "         Secret : $SecretName"
Write-Host ""

$KvUri = "https://$KvName.vault.azure.net/secrets/$SecretName`?api-version=$ApiVersion"

$SecretResponse = Invoke-WebRequest -Uri $KvUri `
    -Headers @{ Authorization = "Bearer $Token" } `
    -UseBasicParsing

$SecretValue = ($SecretResponse.Content | ConvertFrom-Json).value

if (-not $SecretValue) {
    Write-Host "[!] Failed to retrieve secret. Check the RBAC assignment and vault name."
    exit 1
}

Write-Host "[+] Secret retrieved successfully."
Write-Host ""
Write-Host "    Secret value: $SecretValue"
Write-Host ""
Write-Host "============================================================"
Write-Host "  SUCCESS -- No credentials were stored, passed, or required"
Write-Host "  at any point in this retrieval flow."
Write-Host "============================================================"
