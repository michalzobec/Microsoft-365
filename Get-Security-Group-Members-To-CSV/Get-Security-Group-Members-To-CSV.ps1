<#
.SYNOPSIS
Get Security Group Members to CSV

.VERSION
    24.10.03.140059

.SHORTVERSION
    24.10.1

.DESCRIPTION
Get Security Group Members to CSV
(c) 2021-2024 Michal Zobec, ZOBEC Consulting. All Rights Reserved.  
web: www.michalzobec.cz, mail: michal@zobec.net  
GitHub repository http://zob.ec/
#>

# Function to retrieve specific sections from the script header
function Get-ScriptHeaderSection {
    param(
        [string]$scriptPath,
        [string]$sectionName
    )

    # Load the script content and remove any BOM (Byte Order Mark)
    $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($scriptPath))

    # Dynamically created regex to find the specified section
    $sectionPattern = [regex]::Escape($sectionName) + "\s*(.*)"
    
    # Search for the first instance of the section
    $sectionMatch = $scriptContent | Select-String -Pattern $sectionPattern -AllMatches
    if ($sectionMatch) {
        # Remove the section label and return the value (e.g., version)
        return $sectionMatch.Matches[0].Groups[1].Value.Trim()
    }

    # If the section is not found, return null
    return $null
}

# Get the script name (without extension) and current timestamp
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$scriptName-log-$timestamp.txt"

# Function to log messages (to both file and console)
function Write-Log {
    param (
        [string]$message,
        [string]$type = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$type] $message"
    
    # Log to file
    Add-Content -Path $logFile -Value $logMessage

    # Output to console
    Write-Host $logMessage
}

# Start logging
Write-Log "Script execution started."

try {
    # Retrieve the version, short version, and description from the script header
    $scriptPath = $MyInvocation.MyCommand.Path
    $DESCRIPTION = Get-ScriptHeaderSection -scriptPath $scriptPath -sectionName ".DESCRIPTION"
    $VERSION = Get-ScriptHeaderSection -scriptPath $scriptPath -sectionName ".VERSION"
    $SHORTVERSION = Get-ScriptHeaderSection -scriptPath $scriptPath -sectionName ".SHORTVERSION"

    # Check if all required sections are present
    if (-not $DESCRIPTION -or -not $VERSION -or -not $SHORTVERSION) {
        Write-Log "Error: One or more required sections are missing from the script header." "ERROR"
        exit 1
    }

    # Log the version and description information
    Write-Log "Description: $DESCRIPTION"
    Write-Log "Version: $SHORTVERSION ($VERSION)"

    # Load credentials from CSV file
    $credentialsPath = "app_credentials.csv"  # Path to your CSV file
    if (-Not (Test-Path -Path $credentialsPath)) {
        throw "Credentials file not found: $credentialsPath"
    }

    Write-Log "Loading credentials from CSV file."
    $credentials = Import-Csv -Path $credentialsPath

    # Assign variables from CSV
    $tenantId = $credentials.tenantId
    $clientId = $credentials.clientId
    $clientSecret = $credentials.clientSecret

    Write-Log "Credentials loaded successfully."

    # Load group list from CSV file
    $groupsCsv = "groups-list.csv"  # Path to your groups CSV file
    if (-Not (Test-Path -Path $groupsCsv)) {
        throw "Groups list file not found: $groupsCsv"
    }

    Write-Log "Loading group list from CSV file."
    $groups = Import-Csv -Path $groupsCsv

    # Other variables
    $scope = "https://graph.microsoft.com/.default"
    $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

    Write-Log "Starting authentication process to get access token."

    # Obtain access token
    $body = @{
        client_id     = $clientId
        scope         = $scope
        client_secret = $clientSecret
        grant_type    = "client_credentials"
    }

    $response = Invoke-RestMethod -Method Post -Uri $authUrl -ContentType "application/x-www-form-urlencoded" -Body $body
    $accessToken = $response.access_token

    Write-Log "Access token obtained successfully."

    # Process each group from the CSV file
    foreach ($group in $groups) {
        $groupName = $group.GroupName

        Write-Log "Processing group: $groupName."

        # Get group ID by its name
        $headers = @{
            Authorization = "Bearer $accessToken"
        }
        $groupApiUrl = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$groupName'"
        
        Write-Log "Fetching group ID for group: $groupName."
        $groupData = Invoke-RestMethod -Method Get -Uri $groupApiUrl -Headers $headers
        if (-not $groupData.value) {
            Write-Log "Group '$groupName' not found." "ERROR"
            continue
        }
        $groupId = $groupData.value[0].id

        Write-Log "Group ID for '$groupName' is $groupId."

        # Get group members
        $membersApiUrl = "https://graph.microsoft.com/v1.0/groups/$groupId/members"
        
        Write-Log "Fetching members for group ID: $groupId."
        $membersData = Invoke-RestMethod -Method Get -Uri $membersApiUrl -Headers $headers

        if (-not $membersData.value) {
            Write-Log "No members found for group '$groupName'." "WARNING"
            continue
        }

        Write-Log "Members data fetched successfully for group: $groupName."

        # Create a CSV file with members list for each group
        $csvOutputFile = "Members_$groupName.csv"
        $membersList = foreach ($member in $membersData.value) {
            [pscustomobject]@{
                DisplayName = $member.displayName
                UserPrincipalName = $member.userPrincipalName
                ID = $member.id
            }
        }

        Write-Log "Saving members list to CSV file: $csvOutputFile."
        $membersList | Export-Csv -Path $csvOutputFile -NoTypeInformation -Encoding UTF8

        Write-Log "CSV file successfully created for group: $groupName."
    }

    Write-Log "Script execution completed successfully."

} catch {
    Write-Log "An error occurred: $_" "ERROR"
    throw $_
}
