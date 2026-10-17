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
        } |
        ConvertTo-Json |
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

    return (
        Get-Content `
            $file `
            -Raw |
        ConvertFrom-Json
    )

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