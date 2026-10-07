# ============================================================
# StarGate - Recent Failed Login Investigation
# Script: Get-RecentFailedLogins.ps1
# Purpose:
# Investigate Windows Security Event ID 4625 (failed logons),
# summarize failures by user, identify source information,
# and generate an investigation report.
# ============================================================

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

$ReportFolder = "C:\StarGate\Logs\Failed-Login-Reports"

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

Clear-Host

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " STARGATE FAILED LOGIN INVESTIGATION" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This tool investigates Windows Security Event ID 4625."
Write-Host "Event 4625 = Failed logon attempt."
Write-Host ""

# ------------------------------------------------------------
# Ask for investigation period
# ------------------------------------------------------------

do {
    $HoursInput = Read-Host "How many hours of failed-login history should be investigated?"

    $ValidHours = 0
    $IsValidNumber = [int]::TryParse($HoursInput, [ref]$ValidHours)

    if (-not $IsValidNumber -or $ValidHours -lt 1 -or $ValidHours -gt 720) {
        Write-Host ""
        Write-Host "Invalid input." -ForegroundColor Red
        Write-Host "Enter a whole number between 1 and 720 hours."
        Write-Host ""
        $ValidHours = 0
    }

} until ($ValidHours -gt 0)

$Hours = $ValidHours

$StartTime = (Get-Date).AddHours(-$Hours)
$EndTime   = Get-Date

Write-Host ""
Write-Host "Investigation period:"
Write-Host "Start : $StartTime"
Write-Host "End   : $EndTime"
Write-Host ""
Write-Host "Searching Windows Security log..."
Write-Host ""

# ------------------------------------------------------------
# Test Security log access
# ------------------------------------------------------------

try {

    $SecurityTest = Get-WinEvent -LogName Security -MaxEvents 1 -ErrorAction Stop

    Write-Host "Security log access: SUCCESS" -ForegroundColor Green

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to read the Windows Security log." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Investigation stopped."
    exit 1
}

# ------------------------------------------------------------
# Retrieve Event ID 4625
# ------------------------------------------------------------

try {

    $FailedEvents = @(
        Get-WinEvent -FilterHashtable @{
            LogName   = "Security"
            Id        = 4625
            StartTime = $StartTime
            EndTime   = $EndTime
        } -ErrorAction Stop
    )

}
catch {

    Write-Host ""
    Write-Host "ERROR: Failed-login event search failed." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# ------------------------------------------------------------
# Handle no events
# ------------------------------------------------------------

if ($FailedEvents.Count -eq 0) {

    Write-Host ""
    Write-Host "No Event ID 4625 failed-login events were found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This means no failed logons were recorded during the selected period."
    Write-Host ""

    if (-not (Test-Path $ReportFolder)) {
        New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
    }

    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $ReportPath = Join-Path $ReportFolder "Failed-Login-Investigation-$Timestamp.txt"

    @"
STARGATE FAILED LOGIN INVESTIGATION
===================================

Investigation period:
Start : $StartTime
End   : $EndTime

Security log access: SUCCESS

Event ID 4625 results:
No failed-login events found.

Investigation complete.

Report generated: $(Get-Date)
"@ | Out-File -FilePath $ReportPath -Encoding UTF8

    Write-Host "Report saved to:"
    Write-Host $ReportPath -ForegroundColor Green

    exit 0
}

Write-Host "Failed-login events found: $($FailedEvents.Count)" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# Failure reason translation
# ------------------------------------------------------------

function Get-FailureReasonText {

    param (
        [string]$FailureCode
    )

    switch ($FailureCode) {

        "%%2304" {
            return "Unknown user name or incorrect password"
        }

        "%%2313" {
            return "Account restriction or logon restriction"
        }

        default {
            return "Windows failure code: $FailureCode"
        }
    }
}

# ------------------------------------------------------------
# Parse Event XML
# ------------------------------------------------------------

$ParsedEvents = foreach ($Event in $FailedEvents) {

    try {

        [xml]$Xml = $Event.ToXml()

        $Data = @{}

        foreach ($Node in $Xml.Event.EventData.Data) {

            if ($Node.Name) {
                $Data[$Node.Name] = [string]$Node.'#text'
            }
        }

        # ----------------------------------------------------
        # User
        # ----------------------------------------------------

        $TargetUser = $Data["TargetUserName"]
        $TargetDomain = $Data["TargetDomainName"]

        if ([string]::IsNullOrWhiteSpace($TargetUser) -or $TargetUser -eq "-") {

            $DisplayUser = "Unknown"

        }
        elseif ([string]::IsNullOrWhiteSpace($TargetDomain) -or $TargetDomain -eq "-") {

            $DisplayUser = $TargetUser

        }
        else {

            $DisplayUser = "$TargetDomain\$TargetUser"
        }

        # ----------------------------------------------------
        # Source information
        # ----------------------------------------------------

        $SourceIP = $Data["IpAddress"]

        if ([string]::IsNullOrWhiteSpace($SourceIP) -or $SourceIP -eq "-") {
            $SourceIP = "Not available"
        }

        $SourcePort = $Data["IpPort"]

        if ([string]::IsNullOrWhiteSpace($SourcePort) -or $SourcePort -eq "-") {
            $SourcePort = "Not available"
        }

        $Workstation = $Data["WorkstationName"]

        if ([string]::IsNullOrWhiteSpace($Workstation) -or $Workstation -eq "-") {
            $Workstation = "Not available"
        }

        # ----------------------------------------------------
        # Authentication information
        # ----------------------------------------------------

        $LogonType = $Data["LogonType"]

        if ([string]::IsNullOrWhiteSpace($LogonType) -or $LogonType -eq "-") {
            $LogonType = "Unknown"
        }

        $AuthenticationPackage = $Data["AuthenticationPackageName"]

        if ([string]::IsNullOrWhiteSpace($AuthenticationPackage) -or $AuthenticationPackage -eq "-") {
            $AuthenticationPackage = "Unknown"
        }

        # ----------------------------------------------------
        # Failure reason
        # ----------------------------------------------------

        $FailureCode = $Data["FailureReason"]

        if ([string]::IsNullOrWhiteSpace($FailureCode) -or $FailureCode -eq "-") {
            $FailureCode = "Unknown"
        }

        $FailureReasonText = Get-FailureReasonText -FailureCode $FailureCode

        # ----------------------------------------------------
        # Status / SubStatus
        # ----------------------------------------------------

        $Status = $Data["Status"]

        if ([string]::IsNullOrWhiteSpace($Status) -or $Status -eq "-") {
            $Status = "Not available"
        }

        $SubStatus = $Data["SubStatus"]

        if ([string]::IsNullOrWhiteSpace($SubStatus) -or $SubStatus -eq "-") {
            $SubStatus = "Not available"
        }

        # ----------------------------------------------------
        # Create investigation object
        # ----------------------------------------------------

        [PSCustomObject]@{

            User                  = $DisplayUser
            Timestamp             = $Event.TimeCreated
            SourceIP              = $SourceIP
            SourcePort            = $SourcePort
            Workstation           = $Workstation
            LogonType             = $LogonType
            AuthenticationPackage = $AuthenticationPackage
            FailureReason         = $FailureReasonText
            FailureCode           = $FailureCode
            Status                = $Status
            SubStatus             = $SubStatus
            EventID               = $Event.Id
        }

    }
    catch {

        Write-Host ""
        Write-Host "WARNING: Unable to parse one Event ID 4625." -ForegroundColor Yellow
        Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""

    }
}

# ------------------------------------------------------------
# Verify parsed results
# ------------------------------------------------------------

if (-not $ParsedEvents -or $ParsedEvents.Count -eq 0) {

    Write-Host ""
    Write-Host "Events were found, but none could be parsed successfully." -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

$Summary = $ParsedEvents |
    Group-Object User |
    Sort-Object Count -Descending |
    ForEach-Object {

        [PSCustomObject]@{

            User         = $_.Name
            FailureCount = $_.Count
            FirstFailure = ($_.Group | Sort-Object Timestamp | Select-Object -First 1).Timestamp
            LastFailure  = ($_.Group | Sort-Object Timestamp | Select-Object -Last 1).Timestamp
        }
    }

# ------------------------------------------------------------
# Display summary
# ------------------------------------------------------------

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " FAILED LOGIN SUMMARY" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$Summary | Format-Table -AutoSize

# ------------------------------------------------------------
# Display detailed events
# ------------------------------------------------------------

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " FAILED LOGIN DETAILS" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$ParsedEvents |
    Sort-Object Timestamp |
    Format-Table User, Timestamp, SourceIP, Workstation,
        LogonType, AuthenticationPackage, FailureReason -AutoSize

# ------------------------------------------------------------
# Create report folder
# ------------------------------------------------------------

if (-not (Test-Path $ReportFolder)) {

    New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
}

# ------------------------------------------------------------
# Generate report
# ------------------------------------------------------------

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$ReportPath = Join-Path `
    $ReportFolder `
    "Failed-Login-Investigation-$Timestamp.txt"

$ReportContent = @"

==================================================
 STARGATE FAILED LOGIN INVESTIGATION
==================================================

Investigation period:

Start : $StartTime
End   : $EndTime

Security log access: SUCCESS

Failed-login events found: $($ParsedEvents.Count)

==================================================
 FAILED LOGIN SUMMARY
==================================================

$($Summary | Format-Table -AutoSize | Out-String)

==================================================
 FAILED LOGIN DETAILS
==================================================

$($ParsedEvents |
    Sort-Object Timestamp |
    Format-Table User, Timestamp, SourceIP, SourcePort,
        Workstation, LogonType, AuthenticationPackage,
        FailureReason, FailureCode, Status, SubStatus, EventID -AutoSize |
    Out-String)

==================================================
 INVESTIGATION NOTES
==================================================

Event ID 4625 represents a failed logon attempt.

The investigation identifies:
- User
- Timestamp
- Source IP where available
- Source port where available
- Workstation where available
- Logon type
- Authentication package
- Failure reason
- Windows failure code
- Status
- Substatus

Unknown or unavailable source information is reported explicitly
rather than being treated as a confirmed source.

Report generated:
$(Get-Date)

==================================================
 END OF REPORT
==================================================

"@

$ReportContent | Out-File -FilePath $ReportPath -Encoding UTF8

# ------------------------------------------------------------
# Final result
# ------------------------------------------------------------

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " INVESTIGATION COMPLETE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Total failed-login events : $($ParsedEvents.Count)"
Write-Host "Affected users            : $($Summary.Count)"

Write-Host ""
Write-Host "Report saved to:"
Write-Host $ReportPath -ForegroundColor Green

Write-Host ""