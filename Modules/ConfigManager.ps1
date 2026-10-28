$Global:ConfigFolder = Join-Path $PSScriptRoot "..\Config"
$Global:BackupFolder = Join-Path $PSScriptRoot "..\Backups"
$Global:LogFolder = Join-Path $PSScriptRoot "..\Logs"

function Initialize-LauncherConfiguration {

    # ===============================
    # FOLDERS
    # ===============================

    foreach($folder in @(
        $Global:ConfigFolder,
        $Global:BackupFolder,
        $Global:LogFolder
    )){

        if(!(Test-Path $folder)){

            New-Item `
                -ItemType Directory `
                -Path $folder `
                -Force | Out-Null

        }

    }

    # ===============================
    # settings.json
    # ===============================

    $settingsFile =
        Join-Path $Global:ConfigFolder "settings.json"

    if(!(Test-Path $settingsFile)){

        @{
            selectedUser   = "adm-A0836618"
            lastEnvironment = "DEV"
            updateSource = ""
            cyberArk = @{
                enabled = $false
                baseUrl = ""
                username = ""
                password = ""
                appId = ""
                safe = ""
                accountNameTemplate = "{environment}-{user}"
                allowManualFallback = $true
                authType = "Password"
            }
        } |
        ConvertTo-Json -Depth 20 |
        Set-Content `
            $settingsFile `
            -Encoding UTF8

    }

    # ===============================
    # users.json
    # ===============================

    $usersFile =
        Join-Path $Global:ConfigFolder "users.json"

    if(!(Test-Path $usersFile)){

        @{
            defaultUser = "adm-A0836618"
            users = @(
                "adm-A0836618"
            )
        } |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            $usersFile `
            -Encoding UTF8

    }

    # ===============================
    # favorites.json
    # ===============================

    $favoritesFile =
        Join-Path $Global:ConfigFolder "favorites.json"

    if(!(Test-Path $favoritesFile)){

        @{
            favorites = @()
        } |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            $favoritesFile `
            -Encoding UTF8

    }

    # ===============================
    # applications.json
    # ===============================

    $applicationsFile =
        Join-Path $Global:ConfigFolder "applications.json"

    if(!(Test-Path $applicationsFile)){

        @{
            SSMS = ""
            VisualStudio = ""
            VSCode = ""
            ReportBuilder = ""
            LastScan = ""
        } |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            $applicationsFile `
            -Encoding UTF8

    }

    # ===============================
    # projects.json
    # ===============================

    $projectsFile =
        Join-Path $Global:ConfigFolder "projects.json"

    if(!(Test-Path $projectsFile)){

        @{
            projects = @()
        } |
        ConvertTo-Json -Depth 10 |
        Set-Content `
            $projectsFile `
            -Encoding UTF8

    }

    # ===============================
    # links.json
    # ===============================

    $linksFile =
        Join-Path $Global:ConfigFolder "links.json"

    if(!(Test-Path $linksFile)){

        @{
            links = @()
        } |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            $linksFile `
            -Encoding UTF8

    }

    # ===============================
    # launcher.log
    # ===============================

    $logFile =
        Join-Path $Global:LogFolder "launcher.log"

    if(!(Test-Path $logFile)){

        New-Item `
            -ItemType File `
            -Path $logFile `
            -Force | Out-Null

    }

    # ===============================
    # credentials.json
    # ===============================

    $credentialsFile =
        Join-Path $Global:ConfigFolder "credentials.json"

    if(!(Test-Path $credentialsFile)){

        @{
            credentials = @()
        } |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            $credentialsFile `
            -Encoding UTF8

    }

}

function Ensure-LauncherSettingsShape {

    param(
        [Parameter(Mandatory = $true)]
        [object]$Settings
    )

    if($null -eq $Settings){
        $Settings = [pscustomobject]@{}
    }

    $defaultValues = @{
        selectedUser = "adm-A0836618"
        lastEnvironment = "DEV"
        updateSource = ""
    }

    foreach($property in $defaultValues.Keys){
        if($null -eq $Settings.PSObject.Properties[$property]){
            $Settings | Add-Member -Force -NotePropertyName $property -NotePropertyValue $defaultValues[$property]
        }
    }

    if($null -eq $Settings.PSObject.Properties["cyberArk"]){
        $Settings | Add-Member -Force -NotePropertyName "cyberArk" -NotePropertyValue ([pscustomobject]@{
            enabled = $false
            baseUrl = ""
            loginUrl = "https://aon.cyberark.cloud/privilegecloud/Accounts"
            username = ""
            password = ""
            appId = ""
            safe = ""
            accountNameTemplate = "{environment}-{user}"
            allowManualFallback = $true
            authType = "Password"
            interactiveLogin = $true
        })
    }

    $cyberArk = $Settings.cyberArk
    if($null -eq $cyberArk){
        $cyberArk = [pscustomobject]@{}
        $Settings.cyberArk = $cyberArk
    }

    $cyberArkDefaults = @{
        enabled = $false
        baseUrl = ""
        loginUrl = "https://aon.cyberark.cloud/privilegecloud/Accounts"
        username = ""
        password = ""
        appId = ""
        safe = ""
        accountNameTemplate = "{environment}-{user}"
        allowManualFallback = $true
        authType = "Password"
        interactiveLogin = $true
    }

    foreach($property in $cyberArkDefaults.Keys){
        if($null -eq $cyberArk.PSObject.Properties[$property]){
            $cyberArk | Add-Member -Force -NotePropertyName $property -NotePropertyValue $cyberArkDefaults[$property]
        }
    }

    return $Settings
}

function Get-JsonFile {

    param(
        [string]$FileName
    )

    $file =
        Join-Path `
            $Global:ConfigFolder `
            $FileName

    if(!(Test-Path $file)){

        Initialize-LauncherConfiguration

    }

    $data = Get-Content `
        $file `
        -Raw |
    ConvertFrom-Json

    if($FileName -eq "settings.json"){
        $normalized = Ensure-LauncherSettingsShape -Settings $data
        $normalized | ConvertTo-Json -Depth 20 | Set-Content $file -Encoding UTF8
        return $normalized
    }

    return $data

}

function Save-JsonFile {

    param(
        [string]$FileName,
        [object]$Data
    )

    $file =
        Join-Path `
            $Global:ConfigFolder `
            $FileName

    $Data |
        ConvertTo-Json -Depth 20 |
        Set-Content `
            $file `
            -Encoding UTF8

}

function Backup-Configuration {

    $timestamp =
        Get-Date `
            -Format "yyyyMMdd_HHmmss"

    $backupPath =
        Join-Path `
            $Global:BackupFolder `
            $timestamp

    New-Item `
        -ItemType Directory `
        -Path $backupPath `
        -Force | Out-Null

    Copy-Item `
        "$Global:ConfigFolder\*" `
        $backupPath `
        -Recurse `
        -Force

}

Initialize-LauncherConfiguration