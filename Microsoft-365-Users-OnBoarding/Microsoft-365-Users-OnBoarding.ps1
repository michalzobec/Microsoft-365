<#
.SYNOPSIS
    ZOBEC Consulting
    Microsoft 365 Users OnBoarding
    (c) 2021-2023 ZOBEC Consulting, Michal ZOBEC. All Rights Reserved.

.DESCRIPTION
    Tool for bulk onboarding of users in Microsoft 365 Cloud service.

.OUTPUTS
    Console and log file.

.EXAMPLE
    C:\> Microsoft-365-Users-OnBoarding.ps1

.NOTES
    Version:    23.09.03.182859
    Author:     Michal ZOBEC
    Twitter:    @michalzobec
    Blog:       https://www.michalzobec.cz

.LINK
    Documentation (ReadMe)
    https://github.com/michalzobec/esi-build/blob/master/readme.md

.LINK
    Release Notes (ChangeLog)
    https://github.com/michalzobec/esi-build/blob/master/changelog.md

.LINK
    About this script on my Blog in Czech
    https://www.michalzobec.cz

.LINK
    About this script on my Blog in Czech
    https://www.zobec.cz

.LINK
    About this script on my Blog in Czech
    https://zob.ec/esibuild

#>

# Přihlášení do Microsoft 365
Connect-MsolService

# Cesta k CSV souboru s informacemi o uživatelích včetně jmen, příjmení, e-mailů a hesel
$csvPath = ".\test-import.csv"

# Načtení dat z CSV souboru
$userData = Import-Csv -Path $csvPath -Delimiter ";"

# Pro každý záznam v CSV souboru vytvořit nového uživatele v Microsoft 365
foreach ($user in $userData) {
    $displayName = $user.DisplayName
    $firstName = $user.FirstName
    $lastName = $user.LastName
    $email = $user.Email
    $password = $user.Password

    # Vytvoření nového uživatele s definovanými parametry
    New-MsolUser -DisplayName $displayName -FirstName $firstName -LastName $lastName -UserPrincipalName $email -UsageLocation "CZ"
    
    # Nastavení hesla pro nového uživatele
    Set-MsolUserPassword -UserPrincipalName $email -NewPassword $password -ForceChangePassword $false
}

Write-Host "Uživatelé byli vytvořeni v Microsoft 365."