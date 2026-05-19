# ==============================================================================
# Export-AccessReviewAuditTrail.ps1
# Scenario 11 — Entra Access Reviews
# IDSentinel Solutions | Cleveland Oliver
#
# Purpose:
#   Exports the completed Access Review results from Entra ID Identity
#   Governance — including reviewer decisions, justifications, and
#   enforcement actions — as a CSV for SOC 2 CC6.2 / CC6.3 evidence.
#
# Usage:
#   .\Export-AccessReviewAuditTrail.ps1
#   .\Export-AccessReviewAuditTrail.ps1 -ReviewName "Privileged Users — Quarterly Access Review"
#
# Requirements:
#   - Microsoft.Graph PowerShell module
#   - AccessReview.Read.All permission
# ==============================================================================

param(
    [string]$ReviewName = "Privileged Users — Quarterly Access Review"
)

# ── Config ────────────────────────────────────────────────────────────────────
$OutputDir   = "$PSScriptRoot\..\audit-exports"
$Timestamp   = Get-Date -Format "yyyy-MM-dd_HHmm"
$AuditFile   = "$OutputDir\access-review-audit-trail_$Timestamp.csv"

# ── Connect ───────────────────────────────────────────────────────────────────
Write-Host "`n[*] Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "AccessReview.Read.All","User.Read.All","Directory.Read.All" -NoWelcome

# ── Find Access Review ────────────────────────────────────────────────────────
Write-Host "[*] Searching for Access Review: '$ReviewName'" -ForegroundColor Cyan

$Reviews = Get-MgIdentityGovernanceAccessReviewDefinition -All `
    -Filter "displayName eq '$ReviewName'"

if (-not $Reviews) {
    Write-Host "[!] No Access Review found with name: '$ReviewName'" -ForegroundColor Red
    Write-Host "    Available reviews:" -ForegroundColor Yellow
    Get-MgIdentityGovernanceAccessReviewDefinition -All | Select-Object DisplayName, Id | Format-Table
    exit 1
}

$ReviewDef = $Reviews | Select-Object -First 1
Write-Host "[+] Found review definition: $($ReviewDef.DisplayName) — ID: $($ReviewDef.Id)" -ForegroundColor Green

# ── Get Completed Instances ───────────────────────────────────────────────────
Write-Host "[*] Retrieving completed review instances..." -ForegroundColor Cyan

$Instances = Get-MgIdentityGovernanceAccessReviewDefinitionInstance `
    -AccessReviewScheduleDefinitionId $ReviewDef.Id -All `
    | Where-Object { $_.Status -eq "Completed" }

if ($Instances.Count -eq 0) {
    Write-Host "[!] No completed instances found. Review may still be in progress." -ForegroundColor Yellow
    exit 0
}

Write-Host "[+] Completed instances found: $($Instances.Count)" -ForegroundColor Green

# ── Export Decisions ──────────────────────────────────────────────────────────
$AuditTrail = @()

foreach ($Instance in $Instances) {
    Write-Host "[*] Processing instance: $($Instance.Id) — Period: $($Instance.StartDateTime) to $($Instance.EndDateTime)" -ForegroundColor Cyan

    $Decisions = Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision `
        -AccessReviewScheduleDefinitionId $ReviewDef.Id `
        -AccessReviewInstanceId $Instance.Id `
        -All

    foreach ($Decision in $Decisions) {
        $ReviewerName = "Auto / System"
        $ReviewerUPN  = "system@auto-applied"

        if ($Decision.ReviewedBy -and $Decision.ReviewedBy.UserPrincipalName) {
            $ReviewerUPN  = $Decision.ReviewedBy.UserPrincipalName
            $ReviewerName = $Decision.ReviewedBy.DisplayName
        }

        $AuditTrail += [PSCustomObject]@{
            ReviewName       = $ReviewDef.DisplayName
            InstanceId       = $Instance.Id
            ReviewPeriodStart = $Instance.StartDateTime.ToString("yyyy-MM-dd")
            ReviewPeriodEnd  = $Instance.EndDateTime.ToString("yyyy-MM-dd")
            MemberDisplayName = $Decision.Principal.DisplayName
            MemberUPN        = $Decision.Principal.UserPrincipalName
            Decision         = $Decision.Decision          # Approve / Deny / NotReviewed
            Justification    = $Decision.Justification
            ReviewerName     = $ReviewerName
            ReviewerUPN      = $ReviewerUPN
            DecisionDateTime = if ($Decision.ReviewedDateTime) {
                                   $Decision.ReviewedDateTime.ToString("yyyy-MM-dd HH:mm")
                               } else { "Auto-applied" }
            AppliedDateTime  = if ($Decision.AppliedDateTime) {
                                   $Decision.AppliedDateTime.ToString("yyyy-MM-dd HH:mm")
                               } else { "Pending" }
            ApplyResult      = $Decision.ApplyResult      # Applied / NotApplied
        }
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "`n── Access Review Audit Trail ─────────────────────────────────" -ForegroundColor Cyan
$AuditTrail | Format-Table MemberDisplayName, Decision, ReviewerName, Justification -AutoSize

$Approved    = ($AuditTrail | Where-Object { $_.Decision -eq "Approve" }).Count
$Denied      = ($AuditTrail | Where-Object { $_.Decision -eq "Deny" }).Count
$NotReviewed = ($AuditTrail | Where-Object { $_.Decision -eq "NotReviewed" }).Count

Write-Host "`n── Decision Summary ──────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Approved    : $Approved" -ForegroundColor Green
Write-Host "  Denied      : $Denied"   -ForegroundColor Red
Write-Host "  Not Reviewed: $NotReviewed (auto-removed per policy)" -ForegroundColor Yellow
Write-Host "  Total       : $($AuditTrail.Count)"

# ── Export CSV ────────────────────────────────────────────────────────────────
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
$AuditTrail | Export-Csv -Path $AuditFile -NoTypeInformation -Encoding UTF8

Write-Host "`n[+] Audit trail exported: $AuditFile" -ForegroundColor Green
Write-Host "[i] Submit this file as SOC 2 CC6.2 / CC6.3 evidence for the completed review cycle.`n" -ForegroundColor DarkCyan
