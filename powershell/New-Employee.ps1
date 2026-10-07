#requires -Modules ActiveDirectory

<#
.SYNOPSIS
    StarGate Employee Onboarding Automation

.DESCRIPTION
    Creates a new StarGate Active Directory employee account.

    Workflow:
    1. Identify administrator
    2. Verify Active Directory connectivity
    3. Collect employee information
    4. Validate employee information
    5. Determine username and email
    6. Determine correct Organizational Unit
    7. Determine department security group
    8. Collect and validate initial password
    9. Display complete review
    10. Require administrator confirmation
    11. Create Active Directory account
    12. Add department security group
    13. Verify account configuration
    14. Generate onboarding report

.NOTES
    StarGate Technologies
    Domain: stargate.local
    Email domain: stargate.com

    This script does NOT:
    - Assign privileged administrator groups
    - Add users to IT administrator groups
    - Write passwords to reports
    - Automatically create missing security groups
#>

Clear-Host

# ============================================================
# CONFIGURATION
# ============================================================

$DomainName = "stargate.local"
$EmailDomain = "stargate.com"

$ReportFolder = "C:\StarGate\Logs\Employee-Onboarding"

$DefaultDomainUsersGroup = "Domain Users"

# ============================================================
# STAR GATE OU MAPPING
# ============================================================

$DepartmentOU = @{
    "Engineering"     = "OU=Engineering,OU=corporate-users,DC=stargate,DC=local"
    "Finance"         = "OU=Finance,OU=corporate-users,DC=stargate,DC=local"
    "HumanResources"  = "OU=HumanResources,OU=corporate-users,DC=stargate,DC=local"
    "IT"              = "OU=IT,OU=corporate-users,DC=stargate,DC=local"
    "Management"      = "OU=Management,OU=corporate-users,DC=stargate,DC=local"
    "Marketing"       = "OU=Marketing,OU=corporate-users,DC=stargate,DC=local"
    "Operations"      = "OU=Operations,OU=corporate-users,DC=stargate,DC=local"
    "Sales"            = "OU=Sales,OU=corporate-users,DC=stargate,DC=local"
}

# ============================================================
# STAR GATE DEPARTMENT GROUP MAPPING
# ============================================================

$DepartmentGroup = @{
    "Engineering"     = "SG-Engineering"
    "Finance"         = "SG-Finance"
    "HumanResources"  = "SG-HumanResources"
    "IT"              = "SG-IT"
    "Management"      = "SG-Management"
    "Marketing"       = "SG-Marketing"
    "Operations"      = "SG-Operations"
    "Sales"            = "SG-Sales"
}

# ============================================================
# FUNCTIONS
# ============================================================

function Write-Section {
    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Read-RequiredValue {
    param(
        [string]$Prompt
    )

    do {
        $Value = Read-Host $Prompt

        if ([string]::IsNullOrWhiteSpace($Value)) {
            Write-Host "This field cannot be empty." -ForegroundColor Yellow
        }

    } while ([string]::IsNullOrWhiteSpace($Value))

    return $Value.Trim()
}

function Test-ValidDate {
    param(
        [string]$DateText
    )

    try {
        $ParsedDate = [datetime]::ParseExact(
            $DateText,
            "yyyy-MM-dd",
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        return $true
    }
    catch {
        return $false
    }
}

function Convert-ToUsernamePart {
    param(
        [string]$Value
    )

    return ($Value -replace '[^a-zA-Z0-9]', '').ToLower()
}

# ============================================================
# START
# ============================================================

Write-Section "STARGATE EMPLOYEE ONBOARDING"

Write-Host "Purpose:" -ForegroundColor White
Write-Host "Create and configure a new StarGate employee account."

Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Yellow
Write-Host "This script will make Active Directory changes only after"
Write-Host "the administrator reviews and confirms the request."

Write-Host ""
Write-Host "Administrator running onboarding : $env:USERDOMAIN\$env:USERNAME"

# ============================================================
# REPORT FOLDER
# ============================================================

try {

    if (-not (Test-Path $ReportFolder)) {

        New-Item `
            -Path $ReportFolder `
            -ItemType Directory `
            -Force `
            -ErrorAction Stop | Out-Null
    }

}
catch {

    Write-Host ""
    Write-Host "ERROR: Could not create report folder." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit
}

# ============================================================
# ACTIVE DIRECTORY CONNECTION
# ============================================================

Write-Section "ACTIVE DIRECTORY CONNECTION"

try {

    Import-Module ActiveDirectory -ErrorAction Stop

    $Domain = Get-ADDomain -Identity $DomainName -ErrorAction Stop

    Write-Host "Active Directory connection : SUCCESS" -ForegroundColor Green
    Write-Host "Domain                     : $($Domain.DNSRoot)" -ForegroundColor Green
}
catch {

    Write-Host "Active Directory connection : FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit
}

# ============================================================
# EMPLOYEE INFORMATION
# ============================================================

Write-Section "EMPLOYEE INFORMATION"

Write-Host "Enter the new employee's information."
Write-Host ""

$EmployeeID = Read-RequiredValue "Employee ID"
$FirstName = Read-RequiredValue "First Name"
$LastName = Read-RequiredValue "Last Name"

# ============================================================
# DEPARTMENT SELECTION
# ============================================================

$DepartmentOptions = @(
    "Engineering"
    "Finance"
    "HumanResources"
    "IT"
    "Management"
    "Marketing"
    "Operations"
    "Sales"
)

Write-Host ""
Write-Host "Available departments:" -ForegroundColor Cyan
Write-Host ""

for ($i = 0; $i -lt $DepartmentOptions.Count; $i++) {

    Write-Host "[$($i + 1)] $($DepartmentOptions[$i])"
}

do {

    $DepartmentChoice = Read-Host "Enter department number"

    $DepartmentNumber = 0

    $ValidNumber = [int]::TryParse(
        $DepartmentChoice,
        [ref]$DepartmentNumber
    )

    if (
        $ValidNumber -and
        $DepartmentNumber -ge 1 -and
        $DepartmentNumber -le $DepartmentOptions.Count
    ) {

        $Department = $DepartmentOptions[$DepartmentNumber - 1]

        Write-Host "Selected department: $Department" -ForegroundColor Green

        break
    }

    Write-Host ""
    Write-Host "Please select a valid department number (1-$($DepartmentOptions.Count))." -ForegroundColor Yellow

} while ($true)

# ============================================================
# JOB INFORMATION
# ============================================================

$JobTitle = Read-RequiredValue "Job Title"

$ManagerUsername = Read-Host "Manager username (leave blank if none)"

# ============================================================
# LOCATION
# ============================================================

Write-Host ""
Write-Host "Available office locations:" -ForegroundColor Cyan
Write-Host "[1] USA"
Write-Host "[2] Europe"

do {

    $LocationChoice = Read-Host "Enter location number"

    switch ($LocationChoice) {

        "1" {
            $OfficeLocation = "USA"
            break
        }

        "2" {
            $OfficeLocation = "Europe"
            break
        }

        default {
            Write-Host "Please enter 1 or 2." -ForegroundColor Yellow
        }
    }

} while ($OfficeLocation -notin @("USA", "Europe"))

# ============================================================
# START DATE
# ============================================================

do {

    $StartDate = Read-Host "Start Date (YYYY-MM-DD)"

    if (-not (Test-ValidDate $StartDate)) {

        Write-Host "Invalid date. Use YYYY-MM-DD." -ForegroundColor Yellow

    }

} while (-not (Test-ValidDate $StartDate))

# ============================================================
# ACCOUNT IDENTIFIERS
# ============================================================

Write-Section "ACCOUNT IDENTIFIERS"

$FirstNamePart = Convert-ToUsernamePart $FirstName
$LastNamePart = Convert-ToUsernamePart $LastName

$SamAccountName = "$FirstNamePart.$LastNamePart"
$UserPrincipalName = "$SamAccountName@$DomainName"
$EmailAddress = "$SamAccountName@$EmailDomain"

$DisplayName = "$FirstName $LastName"

Write-Host "Display Name       : $DisplayName"
Write-Host "Username           : $SamAccountName"
Write-Host "User Principal Name: $UserPrincipalName"
Write-Host "Email              : $EmailAddress"

# ============================================================
# DUPLICATE USER CHECK
# ============================================================

Write-Host ""
Write-Host "Checking for existing account..." -ForegroundColor Cyan

try {

    $ExistingUser = Get-ADUser `
        -Filter "SamAccountName -eq '$SamAccountName'" `
        -ErrorAction Stop

    if ($ExistingUser) {

        Write-Host ""
        Write-Host "ERROR: Username already exists." -ForegroundColor Red
        Write-Host "Existing account: $($ExistingUser.SamAccountName)" -ForegroundColor Red
        Write-Host "No changes were made." -ForegroundColor Yellow

        exit
    }

    Write-Host "Username availability: AVAILABLE" -ForegroundColor Green

}
catch {

    Write-Host ""
    Write-Host "ERROR while checking username." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit
}

# ============================================================
# OU VALIDATION
# ============================================================

Write-Section "ORGANIZATIONAL UNIT VALIDATION"

$TargetOU = $DepartmentOU[$Department]

Write-Host "Target Organizational Unit:"
Write-Host $TargetOU

try {

    $OUObject = Get-ADOrganizationalUnit `
        -Identity $TargetOU `
        -ErrorAction Stop

    Write-Host "Target OU validation: SUCCESS" -ForegroundColor Green
}
catch {

    Write-Host "ERROR: Target OU does not exist." -ForegroundColor Red
    Write-Host $TargetOU -ForegroundColor Red
    Write-Host "No changes were made." -ForegroundColor Yellow

    exit
}

# ============================================================
# DEPARTMENT GROUP VALIDATION
# ============================================================

Write-Section "DEPARTMENT GROUP VALIDATION"

$TargetGroup = $DepartmentGroup[$Department]

Write-Host "Department security group:"
Write-Host $TargetGroup

try {

    $GroupObject = Get-ADGroup `
        -Identity $TargetGroup `
        -ErrorAction Stop

    Write-Host "Department group validation: SUCCESS" -ForegroundColor Green
}
catch {

    Write-Host ""
    Write-Host "ERROR: Department security group does not exist." -ForegroundColor Red
    Write-Host "Expected group: $TargetGroup" -ForegroundColor Red
    Write-Host ""
    Write-Host "No Active Directory changes were made." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This is especially relevant for Marketing if SG-Marketing"
    Write-Host "has not yet been created in the StarGate environment." -ForegroundColor Yellow

    exit
}

# ============================================================
# MANAGER VALIDATION
# ============================================================

$Manager = $null

if (-not [string]::IsNullOrWhiteSpace($ManagerUsername)) {

    Write-Section "MANAGER VALIDATION"

    try {

        $Manager = Get-ADUser `
            -Identity $ManagerUsername `
            -Properties Department,Title `
            -ErrorAction Stop

        Write-Host "Manager found: SUCCESS" -ForegroundColor Green
        Write-Host "Manager Name : $($Manager.Name)"
        Write-Host "Username     : $($Manager.SamAccountName)"
        Write-Host "Department   : $($Manager.Department)"
        Write-Host "Title        : $($Manager.Title)"
    }
    catch {

        Write-Host ""
        Write-Host "ERROR: Manager account was not found." -ForegroundColor Red
        Write-Host "Username entered: $ManagerUsername" -ForegroundColor Red
        Write-Host "No changes were made." -ForegroundColor Yellow

        exit
    }
}
else {

    Write-Host ""
    Write-Host "No manager specified." -ForegroundColor Yellow
}

# ============================================================
# INITIAL PASSWORD
# ============================================================

Write-Section "INITIAL PASSWORD"

Write-Host "The password will NOT be stored in the onboarding report."
Write-Host "The password must meet the StarGate domain password policy."
Write-Host ""

do {

    $Password = Read-Host "Enter temporary password" -AsSecureString

    $PasswordConfirm = Read-Host "Confirm temporary password" -AsSecureString

    $PasswordText = [System.Net.NetworkCredential]::new(
        "",
        $Password
    ).Password

    $PasswordConfirmText = [System.Net.NetworkCredential]::new(
        "",
        $PasswordConfirm
    ).Password

    if ($PasswordText.Length -lt 12) {

        Write-Host ""
        Write-Host "Password must contain at least 12 characters." -ForegroundColor Yellow

        $PasswordsMatch = $false
    }
    elseif ($PasswordText -cne $PasswordConfirmText) {

        Write-Host ""
        Write-Host "Passwords do not match." -ForegroundColor Yellow

        $PasswordsMatch = $false
    }
    else {

        $PasswordsMatch = $true
    }

} while (-not $PasswordsMatch)

$SecurePassword = $Password

# Clear plaintext password variables
$PasswordText = $null
$PasswordConfirmText = $null
$PasswordConfirm = $null

# ============================================================
# FINAL REVIEW
# ============================================================

Write-Section "ONBOARDING REVIEW"

Write-Host "Please review the information below."
Write-Host ""

Write-Host "Employee ID       : $EmployeeID"
Write-Host "Name              : $DisplayName"
Write-Host "Username          : $SamAccountName"
Write-Host "UPN               : $UserPrincipalName"
Write-Host "Email             : $EmailAddress"
Write-Host "Department        : $Department"
Write-Host "Job Title         : $JobTitle"
Write-Host "Office Location   : $OfficeLocation"
Write-Host "Start Date        : $StartDate"

if ($Manager) {
    Write-Host "Manager           : $($Manager.Name) [$($Manager.SamAccountName)]"
}
else {
    Write-Host "Manager           : None"
}

Write-Host ""
Write-Host "Target OU:"
Write-Host $TargetOU

Write-Host ""
Write-Host "Department Group:"
Write-Host $TargetGroup

Write-Host ""
Write-Host "Initial configuration:"
Write-Host " - Account enabled"
Write-Host " - Password change required at first login"
Write-Host " - Department security group assigned"
Write-Host " - No privileged administrator groups assigned"
Write-Host " - Account placed in department OU"

Write-Host ""
Write-Host "WARNING:" -ForegroundColor Yellow
Write-Host "The next step will create the Active Directory account."
Write-Host "This action will make real changes to the StarGate domain."

Write-Host ""

$FinalConfirmation = Read-Host "Create this employee account? Enter Y to continue or N to cancel"

if ($FinalConfirmation -notmatch '^[Yy]$') {

    Write-Host ""
    Write-Host "Onboarding cancelled." -ForegroundColor Yellow
    Write-Host "No Active Directory changes were made."

    exit
}

# ============================================================
# CREATE AD ACCOUNT
# ============================================================

Write-Section "CREATING ACTIVE DIRECTORY ACCOUNT"

$CreationSuccessful = $false
$GroupAdditionSuccessful = $false
$VerificationSuccessful = $false

try {

    $NewUserParameters = @{
        Name                  = $DisplayName
        GivenName             = $FirstName
        Surname               = $LastName
        DisplayName           = $DisplayName
        SamAccountName        = $SamAccountName
        UserPrincipalName     = $UserPrincipalName
        EmailAddress          = $EmailAddress
        EmployeeID            = $EmployeeID
        Department            = $Department
        Title                 = $JobTitle
        Office                = $OfficeLocation
        Path                  = $TargetOU
        AccountPassword       = $SecurePassword
        Enabled               = $true
        ChangePasswordAtLogon = $true
        ErrorAction           = "Stop"
    }

    if ($Manager) {
        $NewUserParameters["Manager"] = $Manager.DistinguishedName
    }

    New-ADUser @NewUserParameters

    $CreationSuccessful = $true

    Write-Host "Active Directory account creation: SUCCESS" -ForegroundColor Green
}
catch {

    Write-Host ""
    Write-Host "ERROR: Active Directory account creation failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "No further onboarding actions will be performed." -ForegroundColor Yellow

    exit
}

# ============================================================
# ADD DEPARTMENT GROUP
# ============================================================

Write-Section "DEPARTMENT ACCESS"

if ($CreationSuccessful) {

    try {

        Add-ADGroupMember `
            -Identity $TargetGroup `
            -Members $SamAccountName `
            -ErrorAction Stop

        $GroupAdditionSuccessful = $true

        Write-Host "Department group assignment: SUCCESS" -ForegroundColor Green
        Write-Host "Added to: $TargetGroup"

    }
    catch {

        Write-Host ""
        Write-Host "ERROR: Department group assignment failed." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        Write-Host ""
        Write-Host "The account was created, but department access was NOT assigned." -ForegroundColor Yellow
        Write-Host "Manual remediation is required."

    }
}

# ============================================================
# ACCOUNT VERIFICATION
# ============================================================

Write-Section "ACCOUNT VERIFICATION"

try {

    $CreatedUser = Get-ADUser `
        -Identity $SamAccountName `
        -Properties `
            EmployeeID,
            Department,
            Title,
            Office,
            Enabled,
            DistinguishedName,
            UserPrincipalName,
            EmailAddress,
            Manager,
            PasswordLastSet,
            PasswordNeverExpires `
        -ErrorAction Stop

    Write-Host "Account found                 : YES"
    Write-Host "Enabled                      : $($CreatedUser.Enabled)"
    Write-Host "Employee ID                  : $($CreatedUser.EmployeeID)"
    Write-Host "Department                   : $($CreatedUser.Department)"
    Write-Host "Job Title                    : $($CreatedUser.Title)"
    Write-Host "Office                       : $($CreatedUser.Office)"
    Write-Host "User Principal Name          : $($CreatedUser.UserPrincipalName)"
    Write-Host "Email                        : $($CreatedUser.EmailAddress)"
    Write-Host "Organizational Unit location : $($CreatedUser.DistinguishedName)"

    $MembershipCheck = Get-ADGroupMember `
        -Identity $TargetGroup `
        -ErrorAction Stop |
        Where-Object {
            $_.SamAccountName -eq $SamAccountName
        }

    if ($MembershipCheck) {

        Write-Host "Department group membership  : VERIFIED" -ForegroundColor Green
    }
    else {

        Write-Host "Department group membership  : NOT VERIFIED" -ForegroundColor Yellow
    }

    $VerificationSuccessful = $true

}
catch {

    Write-Host ""
    Write-Host "ERROR during account verification." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# ============================================================
# GENERATE REPORT
# ============================================================

Write-Section "GENERATING ONBOARDING REPORT"

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$ReportPath = Join-Path `
    $ReportFolder `
    "Onboarding-$DisplayName-$Timestamp.txt"

$ReportLines = @()

$ReportLines += "============================================================"
$ReportLines += "STARGATE EMPLOYEE ONBOARDING REPORT"
$ReportLines += "============================================================"
$ReportLines += ""
$ReportLines += "Generated             : $(Get-Date)"
$ReportLines += "Administrator         : $env:USERDOMAIN\$env:USERNAME"
$ReportLines += "Domain                : $DomainName"
$ReportLines += ""
$ReportLines += "EMPLOYEE INFORMATION"
$ReportLines += "------------------------------------------------------------"
$ReportLines += "Employee ID           : $EmployeeID"
$ReportLines += "Name                  : $DisplayName"
$ReportLines += "Username              : $SamAccountName"
$ReportLines += "User Principal Name   : $UserPrincipalName"
$ReportLines += "Email                 : $EmailAddress"
$ReportLines += "Department            : $Department"
$ReportLines += "Job Title             : $JobTitle"
$ReportLines += "Office Location       : $OfficeLocation"
$ReportLines += "Start Date            : $StartDate"

if ($Manager) {
    $ReportLines += "Manager               : $($Manager.Name)"
    $ReportLines += "Manager Username      : $($Manager.SamAccountName)"
}
else {
    $ReportLines += "Manager               : None"
}

$ReportLines += ""
$ReportLines += "ACCOUNT CONFIGURATION"
$ReportLines += "------------------------------------------------------------"
$ReportLines += "Target OU             : $TargetOU"
$ReportLines += "Department Group      : $TargetGroup"
$ReportLines += "Account Created       : $CreationSuccessful"
$ReportLines += "Group Assignment      : $GroupAdditionSuccessful"
$ReportLines += "Verification          : $VerificationSuccessful"
$ReportLines += "Privileged Access     : NOT ASSIGNED"
$ReportLines += "Password Logged       : NO"

if ($CreatedUser) {

    $ReportLines += ""
    $ReportLines += "VERIFIED AD STATE"
    $ReportLines += "------------------------------------------------------------"
    $ReportLines += "Enabled               : $($CreatedUser.Enabled)"
    $ReportLines += "Employee ID           : $($CreatedUser.EmployeeID)"
    $ReportLines += "Department            : $($CreatedUser.Department)"
    $ReportLines += "Title                 : $($CreatedUser.Title)"
    $ReportLines += "Office                : $($CreatedUser.Office)"
    $ReportLines += "Password Never Expires: $($CreatedUser.PasswordNeverExpires)"
    $ReportLines += "Distinguished Name    : $($CreatedUser.DistinguishedName)"
}

$ReportLines += ""
$ReportLines += "SECURITY NOTES"
$ReportLines += "------------------------------------------------------------"
$ReportLines += "The account was assigned only to the normal department"
$ReportLines += "security group."
$ReportLines += "No privileged administrator groups were assigned."
$ReportLines += "The temporary password was not written to this report."
$ReportLines += ""
$ReportLines += "============================================================"

try {

    $ReportLines |
        Out-File `
            -FilePath $ReportPath `
            -Encoding UTF8 `
            -Force `
            -ErrorAction Stop

    Write-Host "Report created successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "Report location:"
    Write-Host $ReportPath -ForegroundColor Cyan

}
catch {

    Write-Host ""
    Write-Host "WARNING: Account processing completed, but report creation failed." -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# ============================================================
# FINAL RESULT
# ============================================================

Write-Section "STARGATE ONBOARDING RESULT"

if (
    $CreationSuccessful -and
    $GroupAdditionSuccessful -and
    $VerificationSuccessful
) {

    Write-Host "ONBOARDING STATUS: SUCCESS" -ForegroundColor Green

    Write-Host ""
    Write-Host "Employee account : $SamAccountName"
    Write-Host "Department       : $Department"
    Write-Host "Department group : $TargetGroup"
    Write-Host "Target OU        : $TargetOU"

    Write-Host ""
    Write-Host "The account was created, access was assigned, and"
    Write-Host "the resulting Active Directory configuration was verified."

}
elseif ($CreationSuccessful) {

    Write-Host "ONBOARDING STATUS: PARTIAL" -ForegroundColor Yellow

    Write-Host ""
    Write-Host "The Active Directory account was created."
    Write-Host "One or more subsequent onboarding actions require review."

}
else {

    Write-Host "ONBOARDING STATUS: FAILED" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================================"
Write-Host "END OF ONBOARDING"
Write-Host "============================================================"