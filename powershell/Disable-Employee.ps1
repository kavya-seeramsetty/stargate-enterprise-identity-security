# ============================================================
# StarGate - Employee Offboarding Automation
# ============================================================

Import-Module ActiveDirectory

# 1. INITIAL CONFIRMATION
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " STAR GATE EMPLOYEE OFFBOARDING" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$StartChoice = Read-Host "Are you sure you want to offboard an employee? (Y/N)"

if ($StartChoice -notmatch '^[Yy]$') {
    Write-Host ""
    Write-Host "Offboarding cancelled." -ForegroundColor Yellow
    Write-Host "No changes were made."
    Write-Host ""
    exit
}

# 2. IDENTIFY CURRENT ADMINISTRATOR
$CurrentAdmin = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host ""
Write-Host "Administrator: $CurrentAdmin"
Write-Host ""

# 3. AUTHORIZATION CHECK
$AuthorizedAdmins = @(
    "STARGATE\adm.domain.admin",
    "STARGATE\adm.identity.admin",
    "STARGATE\adm.betty.gutierrez"
)

if ($AuthorizedAdmins -notcontains $CurrentAdmin) {
    Write-Host "ACCESS DENIED" -ForegroundColor Red
    Write-Host ""
    Write-Host "This administrator is not authorized to perform employee offboarding."
    Write-Host ""
    exit
}

Write-Host "Authorization check: PASSED" -ForegroundColor Green
Write-Host ""

# 4. CONFIGURATION
$DomainDN = "DC=stargate,DC=local"
$DisabledUsersOU = "OU=Disabled-Users,$DomainDN"
$ReportFolder = "C:\StarGate\Logs\Offboarding-Reports"

# 5. CREATE DISABLED-USERS OU IF REQUIRED
try {
    $ExistingOU = Get-ADOrganizationalUnit -Identity $DisabledUsersOU -ErrorAction Stop
    Write-Host "Disabled-Users OU: FOUND" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "Disabled-Users OU was not found." -ForegroundColor Yellow
    Write-Host "Creating Disabled-Users OU..." -ForegroundColor Yellow
    Write-Host ""

    try {
        New-ADOrganizationalUnit `
            -Name "Disabled-Users" `
            -Path $DomainDN `
            -Description "Disabled employee accounts - StarGate offboarding" `
            -ProtectedFromAccidentalDeletion $true `
            -ErrorAction Stop

        Write-Host "Disabled-Users OU created successfully." -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Host "ERROR: Could not create Disabled-Users OU." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        exit
    }
}

# 6. ASK FOR EMPLOYEE NAME
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " EMPLOYEE IDENTIFICATION" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$FirstName = Read-Host "Enter employee FIRST NAME"
$LastName = Read-Host "Enter employee LAST NAME"

if ([string]::IsNullOrWhiteSpace($FirstName) -or [string]::IsNullOrWhiteSpace($LastName)) {
    Write-Host ""
    Write-Host "First name and last name are required." -ForegroundColor Red
    Write-Host "No changes were made."
    Write-Host ""
    exit
}

# 7. FIND EMPLOYEE
$SearchName = "$FirstName $LastName"

try {
    $Employees = @(
        Get-ADUser `
            -Filter {
                GivenName -eq $FirstName -and
                Surname -eq $LastName
            } `
            -Properties `
                GivenName,
                Surname,
                Department,
                Title,
                EmployeeID,
                Manager,
                Enabled,
                LockedOut,
                DistinguishedName,
                MemberOf,
                LastLogonDate,
                PasswordLastSet `
            -ErrorAction Stop
    )
}
catch {
    Write-Host ""
    Write-Host "ERROR while searching Active Directory." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    exit
}

# 8. HANDLE SEARCH RESULTS
if ($Employees.Count -eq 0) {
    Write-Host ""
    Write-Host "EMPLOYEE NOT FOUND" -ForegroundColor Red
    Write-Host ""
    Write-Host "No employee was found for:"
    Write-Host $SearchName
    Write-Host ""
    Write-Host "No changes were made."
    Write-Host ""
    exit
}

if ($Employees.Count -gt 1) {
    Write-Host ""
    Write-Host "MULTIPLE EMPLOYEES FOUND" -ForegroundColor Yellow
    Write-Host ""

    $Number = 1
    foreach ($Person in $Employees) {
        Write-Host "[$Number] $($Person.Name)"
        Write-Host "    Username   : $($Person.SamAccountName)"
        Write-Host "    Department : $($Person.Department)"
        Write-Host "    Job Title  : $($Person.Title)"
        Write-Host ""
        $Number++
    }

    $Selection = Read-Host "Enter the employee number"
    $SelectionNumber = 0

    $ValidNumber = [int]::TryParse($Selection, [ref]$SelectionNumber)

    if (-not $ValidNumber -or $SelectionNumber -lt 1 -or $SelectionNumber -gt $Employees.Count) {
        Write-Host ""
        Write-Host "Invalid selection." -ForegroundColor Red
        Write-Host "No changes were made."
        Write-Host ""
        exit
    }

    $Employee = $Employees[$SelectionNumber - 1]
}
else {
    $Employee = $Employees[0]
}

# 9. DISPLAY EMPLOYEE DETAILS
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " EMPLOYEE DETAILS" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Name              : $($Employee.Name)"
Write-Host "Username          : $($Employee.SamAccountName)"
Write-Host "Employee ID       : $($Employee.EmployeeID)"
Write-Host "Department        : $($Employee.Department)"
Write-Host "Job Title         : $($Employee.Title)"
Write-Host "Manager           : $($Employee.Manager)"
Write-Host "Account Enabled   : $($Employee.Enabled)"
Write-Host "Account Locked    : $($Employee.LockedOut)"
Write-Host "Last Logon        : $($Employee.LastLogonDate)"
Write-Host "Password Last Set : $($Employee.PasswordLastSet)"
Write-Host "Current Location  : $($Employee.DistinguishedName)"
Write-Host ""

# 10. DISPLAY GROUP MEMBERSHIPS
Write-Host "Current direct group memberships:" -ForegroundColor Yellow
Write-Host ""

$CurrentGroups = @()

foreach ($GroupDN in $Employee.MemberOf) {
    try {
        $Group = Get-ADGroup -Identity $GroupDN -Properties GroupScope,GroupCategory -ErrorAction Stop
        $CurrentGroups += $Group
        Write-Host " - $($Group.Name)"
    }
    catch {
        Write-Host " - Unable to resolve group: $GroupDN" -ForegroundColor Yellow
    }
}

if ($CurrentGroups.Count -eq 0) {
    Write-Host " - No direct group memberships found."
}

Write-Host ""

# 11. VERIFY EMPLOYEE NAME
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " IDENTITY VERIFICATION" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$ConfirmFirstName = Read-Host "Confirm employee FIRST NAME"
$ConfirmLastName = Read-Host "Confirm employee LAST NAME"
$ConfirmedFullName = "$ConfirmFirstName $ConfirmLastName"

if ($ConfirmedFullName.Trim() -ne $Employee.Name.Trim()) {
    Write-Host ""
    Write-Host "IDENTITY VERIFICATION FAILED" -ForegroundColor Red
    Write-Host "The entered name does not match Active Directory."
    Write-Host "No changes were made."
    Write-Host ""
    exit
}

Write-Host "Name verification: PASSED" -ForegroundColor Green
Write-Host ""

# 12. VERIFY DEPARTMENT
$ConfirmDepartment = Read-Host "Confirm employee DEPARTMENT"

if ($ConfirmDepartment.Trim() -ne $Employee.Department.Trim()) {
    Write-Host ""
    Write-Host "DEPARTMENT VERIFICATION FAILED" -ForegroundColor Red
    Write-Host "The entered department does not match Active Directory."
    Write-Host "No changes were made."
    Write-Host ""
    exit
}

Write-Host "Department verification: PASSED" -ForegroundColor Green
Write-Host ""

# 13. FINAL WARNING
Write-Host "==================================================" -ForegroundColor Red
Write-Host " FINAL OFFBOARDING WARNING" -ForegroundColor Red
Write-Host "==================================================" -ForegroundColor Red
Write-Host ""

Write-Host "Employee   : $($Employee.Name)" -ForegroundColor Yellow
Write-Host "Username   : $($Employee.SamAccountName)" -ForegroundColor Yellow
Write-Host "Department : $($Employee.Department)" -ForegroundColor Yellow
Write-Host ""

Write-Host "The following actions will be performed:"
Write-Host " [1] Disable the Active Directory account"
Write-Host " [2] Remove direct security-group memberships"
Write-Host " [3] Retain Domain Users"
Write-Host " [4] Move the account to Disabled-Users"
Write-Host " [5] Verify the changes"
Write-Host " [6] Generate an offboarding report"
Write-Host ""

$FinalConfirmation = Read-Host "Are you sure you want to proceed? (Y/N)"

if ($FinalConfirmation -notmatch '^[Yy]$') {
    Write-Host ""
    Write-Host "OFFBOARDING CANCELLED" -ForegroundColor Yellow
    Write-Host "No changes were made."
    Write-Host ""
    exit
}

# 14. CAPTURE PRE-OFFBOARDING STATE
$ActionTime = Get-Date
$OriginalDN = $Employee.DistinguishedName
$OriginalEnabled = $Employee.Enabled
$OriginalGroups = @($CurrentGroups.Name)

# 15. PREPARE REPORT
New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null

$SafeEmployeeName = $Employee.Name -replace '[\\/:*?"<>|]', '_'
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ReportFile = Join-Path $ReportFolder "Offboarding-$SafeEmployeeName-$Timestamp.txt"

# 16. ACTION TRACKING
$Actions = @()
$OverallSuccess = $true

# 17. DISABLE ACCOUNT
try {
    Disable-ADAccount -Identity $Employee.SamAccountName -ErrorAction Stop
    $Actions += "[SUCCESS] Account disabled"
    Write-Host ""
    Write-Host "Account disabled successfully." -ForegroundColor Green
}
catch {
    $Actions += "[FAILED] Account disable operation"
    Write-Host ""
    Write-Host "Account disable FAILED." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    $OverallSuccess = $false
}

# 18. REMOVE SECURITY GROUP ACCESS
foreach ($Group in $CurrentGroups) {
    if ($Group.Name -eq "Domain Users") {
        $Actions += "[RETAINED] Domain Users"
        continue
    }

    try {
        Remove-ADGroupMember -Identity $Group -Members $Employee -Confirm:$false -ErrorAction Stop
        $Actions += "[SUCCESS] Removed from group: $($Group.Name)"
        Write-Host ""
        Write-Host "Removed from group: $($Group.Name)" -ForegroundColor Green
    }
    catch {
        $Actions += "[FAILED] Could not remove from group: $($Group.Name)"
        Write-Host ""
        Write-Host "Failed to remove from group: $($Group.Name)" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        $OverallSuccess = $false
    }
}

# 19. MOVE ACCOUNT
try {
    Move-ADObject -Identity $Employee.DistinguishedName -TargetPath $DisabledUsersOU -ErrorAction Stop
    $Actions += "[SUCCESS] Account moved to Disabled-Users"
    Write-Host ""
    Write-Host "Account moved to Disabled-Users successfully." -ForegroundColor Green
}
catch {
    $Actions += "[FAILED] Account move operation"
    Write-Host ""
    Write-Host "Account move FAILED." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    $OverallSuccess = $false
}

# 20. FINAL VERIFICATION
try {
    $VerificationUser = Get-ADUser `
        -Identity $Employee.SamAccountName `
        -Properties Enabled,MemberOf,DistinguishedName `
        -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "FINAL VERIFICATION FAILED" -ForegroundColor Red
    Write-Host "The employee account could not be retrieved."
    Write-Host ""
    $OverallSuccess = $false
    $VerificationUser = $null
}

if ($null -ne $VerificationUser) {

    if ($VerificationUser.Enabled -eq $false) {
        $Actions += "[VERIFIED] Account is disabled"
    }
    else {
        $Actions += "[VERIFICATION FAILED] Account is still enabled"
        $OverallSuccess = $false
    }

    if ($VerificationUser.DistinguishedName -like "*OU=Disabled-Users,*") {
        $Actions += "[VERIFIED] Account is in Disabled-Users"
    }
    else {
        $Actions += "[VERIFICATION FAILED] Account is not in Disabled-Users"
        $OverallSuccess = $false
    }

    $RemainingGroups = @()

    foreach ($GroupDN in $VerificationUser.MemberOf) {
        try {
            $RemainingGroup = Get-ADGroup -Identity $GroupDN -ErrorAction Stop
            $RemainingGroups += $RemainingGroup.Name
        }
        catch {
            $RemainingGroups += $GroupDN
        }
    }

    $UnexpectedGroups = @(
        $RemainingGroups | Where-Object { $_ -ne "Domain Users" }
    )

    if ($UnexpectedGroups.Count -eq 0) {
        $Actions += "[VERIFIED] Additional security-group access removed"
    }
    else {
        $Actions += "[VERIFICATION WARNING] Remaining groups: $($UnexpectedGroups -join ', ')"
        $OverallSuccess = $false
    }
}

# 21. OVERALL RESULT
if ($OverallSuccess) {
    $OverallResult = "SUCCESS"
}
else {
    $OverallResult = "PARTIAL / FAILED - REVIEW REQUIRED"
}

# 22. BUILD REPORT
$ReportLines = @()
$ReportLines += "=================================================="
$ReportLines += "STAR GATE EMPLOYEE OFFBOARDING REPORT"
$ReportLines += "=================================================="
$ReportLines += ""
$ReportLines += "Date/Time:"
$ReportLines += "$ActionTime"
$ReportLines += ""
$ReportLines += "Administrator:"
$ReportLines += "$CurrentAdmin"
$ReportLines += ""
$ReportLines += "--------------------------------------------------"
$ReportLines += "EMPLOYEE INFORMATION"
$ReportLines += "--------------------------------------------------"
$ReportLines += ""
$ReportLines += "Name:"
$ReportLines += "$($Employee.Name)"
$ReportLines += "Username:"
$ReportLines += "$($Employee.SamAccountName)"
$ReportLines += "Employee ID:"
$ReportLines += "$($Employee.EmployeeID)"
$ReportLines += "Department:"
$ReportLines += "$($Employee.Department)"
$ReportLines += "Job Title:"
$ReportLines += "$($Employee.Title)"
$ReportLines += "Manager:"
$ReportLines += "$($Employee.Manager)"
$ReportLines += ""
$ReportLines += "--------------------------------------------------"
$ReportLines += "ACCOUNT STATE BEFORE OFFBOARDING"
$ReportLines += "--------------------------------------------------"
$ReportLines += ""
$ReportLines += "Enabled:"
$ReportLines += "$OriginalEnabled"
$ReportLines += "Original Location:"
$ReportLines += "$OriginalDN"
$ReportLines += ""
$ReportLines += "--------------------------------------------------"
$ReportLines += "GROUP MEMBERSHIPS BEFORE OFFBOARDING"
$ReportLines += "--------------------------------------------------"
$ReportLines += ""

if ($OriginalGroups.Count -gt 0) {
    foreach ($GroupName in $OriginalGroups) {
        $ReportLines += "- $GroupName"
    }
}
else {
    $ReportLines += "- No additional group memberships found."
}

$ReportLines += ""
$ReportLines += "--------------------------------------------------"
$ReportLines += "ACTIONS PERFORMED"
$ReportLines += "--------------------------------------------------"
$ReportLines += ""

foreach ($Action in $Actions) {
    $ReportLines += $Action
}

$ReportLines += ""
$ReportLines += "--------------------------------------------------"
$ReportLines += "FINAL STATE"
$ReportLines += "--------------------------------------------------"
$ReportLines += ""

if ($null -ne $VerificationUser) {
    $ReportLines += "Account Enabled:"
    $ReportLines += "$($VerificationUser.Enabled)"
    $ReportLines += ""
    $ReportLines += "Final Location:"
    $ReportLines += "$($VerificationUser.DistinguishedName)"
    $ReportLines += ""
    $ReportLines += "Remaining Group Memberships:"

    if ($RemainingGroups.Count -gt 0) {
        foreach ($GroupName in $RemainingGroups) {
            $ReportLines += "- $GroupName"
        }
    }
    else {
        $ReportLines += "- None"
    }
}

$ReportLines += ""
$ReportLines += "--------------------------------------------------"
$ReportLines += "OVERALL RESULT"
$ReportLines += "--------------------------------------------------"
$ReportLines += ""
$ReportLines += $OverallResult
$ReportLines += ""
$ReportLines += "=================================================="
$ReportLines += "END OF OFFBOARDING REPORT"
$ReportLines += "=================================================="

# 23. SAVE REPORT
$ReportLines | Out-File -FilePath $ReportFile -Encoding UTF8

# 24. FINAL RESULT
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " OFFBOARDING COMPLETE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Employee : $($Employee.Name)"
Write-Host "Username : $($Employee.SamAccountName)"
Write-Host ""
Write-Host "Actions performed:" -ForegroundColor Yellow
Write-Host ""

foreach ($Action in $Actions) {
    if ($Action -like "[SUCCESS]*" -or $Action -like "[VERIFIED]*") {
        Write-Host $Action -ForegroundColor Green
    }
    elseif ($Action -like "[FAILED]*" -or $Action -like "[VERIFICATION FAILED]*") {
        Write-Host $Action -ForegroundColor Red
    }
    else {
        Write-Host $Action -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Overall Result: $OverallResult"
Write-Host ""
Write-Host "Report saved to:" -ForegroundColor Cyan
Write-Host $ReportFile
Write-Host ""
