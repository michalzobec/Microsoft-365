# Load credentials from CSV file
$credentialsPath = "app_credentials.csv"  # Path to your CSV file
$credentials = Import-Csv -Path $credentialsPath

# Assign variables from CSV
$tenantId = $credentials.tenantId
$clientId = $credentials.clientId
$clientSecret = $credentials.clientSecret

# Other variables
$scope = "https://graph.microsoft.com/.default"
$authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$groupName = "License-Atlassian-Confluence-Cloud"
$csvOutputFile = "Members_$groupName.csv"

# Obtain access token
$body = @{
    client_id     = $clientId
    scope         = $scope
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

$response = Invoke-RestMethod -Method Post -Uri $authUrl -ContentType "application/x-www-form-urlencoded" -Body $body
$accessToken = $response.access_token

# Get group ID by its name
$headers = @{
    Authorization = "Bearer $accessToken"
}
$groupApiUrl = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$groupName'"
$groupData = Invoke-RestMethod -Method Get -Uri $groupApiUrl -Headers $headers

$groupId = $groupData.value[0].id

# Get group members
$membersApiUrl = "https://graph.microsoft.com/v1.0/groups/$groupId/members"
$membersData = Invoke-RestMethod -Method Get -Uri $membersApiUrl -Headers $headers

# Create CSV file
$membersList = foreach ($member in $membersData.value) {
    [pscustomobject]@{
        DisplayName = $member.displayName
        UserPrincipalName = $member.userPrincipalName
        ID = $member.id
    }
}

$membersList | Export-Csv -Path $csvOutputFile -NoTypeInformation -Encoding UTF8

Write-Host "Member list successfully saved to $csvOutputFile"
