$Global:LogFile = Join-Path `
    $PSScriptRoot `
    "..\Logs\launcher.log"

function Write-LauncherLog {

    param(
        [string]$Environment,
        [string]$User,
        [string]$Application
    )

    $line =
        "{0} | INFO | {1} | {2} | {3}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        $Environment,
        $User,
        $Application

    Add-Content `
        -Path $Global:LogFile `
        -Value $line

}

function Write-ErrorLog {

    param(
        [string]$Message
    )

    $line =
        "{0} | ERROR | {1}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        $Message

    Add-Content `
        -Path $Global:LogFile `
        -Value $line

}

function Get-LauncherLogs {

    if(!(Test-Path $Global:LogFile)){

        return @()

    }

    return Get-Content $Global:LogFile

}

function Clear-LauncherLogs {

    "" | Set-Content $Global:LogFile

}