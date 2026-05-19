# =============================================================================
# validate-saml-federation.ps1
# Description: Validates the Entra + AWS SAML federation configuration.
#              Checks AWS IAM Identity Provider, federated role trust policy,
#              and permission boundaries before testing the federation flow.
#
# Author:      Cleveland Oliver | IDSentinel Solutions
# Scenario:    12 - Entra + AWS SAML Federation
#
# PREREQUISITES:
#   - AWS CLI installed and configured: aws configure
#   - Your IAM user must have: iam:GetRole, iam:ListSAMLProviders, iam:GetSAMLProvider
#   - PowerShell 5.1+ or PowerShell 7+
#
# HOW TO USE:
#   1. Set the variables in the CONFIG section below
#   2. Run: .\validate-saml-federation.ps1
#   3. Review the output — each check is PASS / FAIL / WARN
# =============================================================================

# ── CONFIG — Update these values ─────────────────────────────────────────────
$AwsAccountId   = "YOUR_ACCOUNT_ID"             # 12-digit AWS account ID
$IdPName        = "IDSentinel-EntraIdP"          # Name given to the SAML IdP in AWS IAM
$RoleName       = "IDSentinel-EntraFed-ReadOnly" # IAM role name for federated access
$ExpectedAudience = "https://signin.aws.amazon.com/saml"
# ─────────────────────────────────────────────────────────────────────────────

$PassCount = 0
$FailCount = 0
$WarnCount = 0

function Write-Check {
    param($Label, $Status, $Detail)
    $color = switch ($Status) {
        "PASS" { "Green"  }
        "FAIL" { "Red"    }
        "WARN" { "Yellow" }
        default { "White" }
    }
    Write-Host ("  [{0}] {1}" -f $Status.PadRight(4), $Label) -ForegroundColor $color
    if ($Detail) { Write-Host ("         → $Detail") -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Scenario 12 — SAML Federation Validation" -ForegroundColor Cyan
Write-Host "  IDSentinel Solutions" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# ── CHECK 1: AWS CLI available ────────────────────────────────────────────────
Write-Host "[ ENVIRONMENT ]" -ForegroundColor White
try {
    $CliVersion = aws --version 2>&1
    Write-Check "AWS CLI installed" "PASS" $CliVersion
    $PassCount++
} catch {
    Write-Check "AWS CLI installed" "FAIL" "Install from https://aws.amazon.com/cli/"
    $FailCount++
    Write-Host ""
    Write-Host "  Cannot continue without AWS CLI. Exiting." -ForegroundColor Red
    exit 1
}

# ── CHECK 2: AWS credentials configured ───────────────────────────────────────
try {
    $Identity = aws sts get-caller-identity --output json 2>&1 | ConvertFrom-Json
    Write-Check "AWS credentials configured" "PASS" ("Account: $($Identity.Account) | User: $($Identity.Arn)")
    $PassCount++
} catch {
    Write-Check "AWS credentials configured" "FAIL" "Run 'aws configure' to set credentials"
    $FailCount++
    exit 1
}

Write-Host ""
Write-Host "[ SAML IDENTITY PROVIDER ]" -ForegroundColor White

# ── CHECK 3: IdP exists ────────────────────────────────────────────────────────
$IdPArn = "arn:aws:iam::${AwsAccountId}:saml-provider/${IdPName}"
try {
    $IdPDetail = aws iam get-saml-provider --saml-provider-arn $IdPArn --output json 2>&1 | ConvertFrom-Json
    if ($IdPDetail.SAMLMetadataDocument) {
        Write-Check "SAML IdP exists in IAM" "PASS" $IdPArn
        $PassCount++
    } else {
        Write-Check "SAML IdP exists in IAM" "FAIL" "IdP found but metadata is empty"
        $FailCount++
    }
} catch {
    Write-Check "SAML IdP exists in IAM" "FAIL" "IdP not found: $IdPArn — complete Stage 3 of the README"
    $FailCount++
}

# ── CHECK 4: IdP metadata is not expired ──────────────────────────────────────
try {
    $IdPDetail = aws iam get-saml-provider --saml-provider-arn $IdPArn --output json 2>&1 | ConvertFrom-Json
    if ($IdPDetail.ValidUntil) {
        $ExpiryDate = [datetime]$IdPDetail.ValidUntil
        $DaysLeft = ($ExpiryDate - (Get-Date)).Days
        if ($DaysLeft -gt 30) {
            Write-Check "IdP metadata not expiring soon" "PASS" ("Expires: $($ExpiryDate.ToString('yyyy-MM-dd')) ($DaysLeft days remaining)")
            $PassCount++
        } elseif ($DaysLeft -gt 0) {
            Write-Check "IdP metadata expiring soon" "WARN" ("Expires in $DaysLeft days — refresh metadata XML in AWS IdP")
            $WarnCount++
        } else {
            Write-Check "IdP metadata expired" "FAIL" ("Expired: $($ExpiryDate.ToString('yyyy-MM-dd')) — re-upload Entra metadata XML immediately")
            $FailCount++
        }
    } else {
        Write-Check "IdP metadata expiry" "WARN" "Could not determine expiry date from metadata"
        $WarnCount++
    }
} catch {
    Write-Check "IdP metadata expiry check" "WARN" "Could not retrieve IdP detail for expiry check"
    $WarnCount++
}

Write-Host ""
Write-Host "[ FEDERATED IAM ROLE ]" -ForegroundColor White

# ── CHECK 5: Role exists ───────────────────────────────────────────────────────
try {
    $Role = aws iam get-role --role-name $RoleName --output json 2>&1 | ConvertFrom-Json
    Write-Check "Federated role exists" "PASS" ("ARN: $($Role.Role.Arn)")
    $PassCount++
} catch {
    Write-Check "Federated role exists" "FAIL" ("Role '$RoleName' not found — complete Stage 4 of the README")
    $FailCount++
}

# ── CHECK 6: Trust policy references correct IdP ──────────────────────────────
try {
    $Role = aws iam get-role --role-name $RoleName --output json 2>&1 | ConvertFrom-Json
    $TrustPolicy = [System.Web.HttpUtility]::UrlDecode($Role.Role.AssumeRolePolicyDocument) | ConvertFrom-Json
    $SamlStatement = $TrustPolicy.Statement | Where-Object { $_.Action -eq "sts:AssumeRoleWithSAML" }
    
    if ($SamlStatement) {
        Write-Check "Trust policy uses sts:AssumeRoleWithSAML" "PASS" ""
        $PassCount++
        
        $FederatedPrincipal = $SamlStatement.Principal.Federated
        if ($FederatedPrincipal -eq $IdPArn) {
            Write-Check "Trust policy references correct IdP ARN" "PASS" $FederatedPrincipal
            $PassCount++
        } else {
            Write-Check "Trust policy references correct IdP ARN" "FAIL" ("Found: $FederatedPrincipal | Expected: $IdPArn")
            $FailCount++
        }
        
        # Check audience condition
        $AudienceCondition = $SamlStatement.Condition.'StringEquals'.'SAML:aud'
        if ($AudienceCondition -eq $ExpectedAudience) {
            Write-Check "SAML audience condition correct" "PASS" $AudienceCondition
            $PassCount++
        } else {
            Write-Check "SAML audience condition" "FAIL" ("Found: '$AudienceCondition' | Expected: '$ExpectedAudience'")
            $FailCount++
        }
    } else {
        Write-Check "Trust policy uses sts:AssumeRoleWithSAML" "FAIL" "No SAML statement found in trust policy"
        $FailCount++
    }
} catch {
    Write-Check "Trust policy validation" "WARN" "Could not parse trust policy — check role manually"
    $WarnCount++
}

# ── CHECK 7: ReadOnlyAccess policy attached ────────────────────────────────────
try {
    $AttachedPolicies = aws iam list-attached-role-policies --role-name $RoleName --output json 2>&1 | ConvertFrom-Json
    $ReadOnly = $AttachedPolicies.AttachedPolicies | Where-Object { $_.PolicyName -eq "ReadOnlyAccess" }
    
    if ($ReadOnly) {
        Write-Check "ReadOnlyAccess policy attached" "PASS" $ReadOnly.PolicyArn
        $PassCount++
    } else {
        $PolicyNames = ($AttachedPolicies.AttachedPolicies | ForEach-Object { $_.PolicyName }) -join ", "
        Write-Check "ReadOnlyAccess policy attached" "FAIL" ("Attached policies: $PolicyNames — ReadOnlyAccess not found")
        $FailCount++
    }
} catch {
    Write-Check "ReadOnlyAccess policy check" "WARN" "Could not retrieve attached policies"
    $WarnCount++
}

Write-Host ""
Write-Host "[ LEAST PRIVILEGE VALIDATION ]" -ForegroundColor White

# ── CHECK 8: Confirm no AdministratorAccess attached ──────────────────────────
try {
    $AttachedPolicies = aws iam list-attached-role-policies --role-name $RoleName --output json 2>&1 | ConvertFrom-Json
    $AdminPolicy = $AttachedPolicies.AttachedPolicies | Where-Object { $_.PolicyName -eq "AdministratorAccess" }
    
    if ($AdminPolicy) {
        Write-Check "No AdministratorAccess attached" "FAIL" "AdministratorAccess is attached — remove immediately"
        $FailCount++
    } else {
        Write-Check "No AdministratorAccess attached" "PASS" "Admin policy not present"
        $PassCount++
    }
} catch {
    Write-Check "Admin policy check" "WARN" "Could not verify — check manually"
    $WarnCount++
}

# ── SUMMARY ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ("  PASS : {0}" -f $PassCount) -ForegroundColor Green
Write-Host ("  WARN : {0}" -f $WarnCount) -ForegroundColor Yellow
Write-Host ("  FAIL : {0}" -f $FailCount) -ForegroundColor Red
Write-Host ""

if ($FailCount -eq 0 -and $WarnCount -eq 0) {
    Write-Host "  ✅ All checks passed. Federation prerequisites met." -ForegroundColor Green
    Write-Host "  Proceed to Stage 5 — Federation Test." -ForegroundColor Green
} elseif ($FailCount -eq 0) {
    Write-Host "  ⚠️  Checks passed with warnings. Review WARN items before testing." -ForegroundColor Yellow
} else {
    Write-Host "  ❌ $FailCount check(s) failed. Resolve FAIL items before testing federation." -ForegroundColor Red
}

Write-Host ""
Write-Host "  ARNs for reference:" -ForegroundColor DarkGray
Write-Host ("  IdP ARN  : arn:aws:iam::${AwsAccountId}:saml-provider/${IdPName}") -ForegroundColor DarkGray
Write-Host ("  Role ARN : arn:aws:iam::${AwsAccountId}:role/${RoleName}") -ForegroundColor DarkGray
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
