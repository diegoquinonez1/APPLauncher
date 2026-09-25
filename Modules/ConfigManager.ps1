$Global:ConfigFolder = Join-Path $PSScriptRoot "..\Config"
$Global:BackupFolder = Join-Path $PSScriptRoot "..\Backups"

function Get-JsonFile {

    param(
        [string]$FileName
    )

    $file = Join-Path $Global:ConfigFolder $FileName

    if(!(Test-Path $file)){
        throw "No existe el archivo $FileName"
    }

    return (
        Get-Content $file -Raw |
        ConvertFrom-Json
    )
}

function Save-JsonFile {

    param(
        [string]$FileName,
        [object]$Data
    )

    $file = Join-Path $Global:ConfigFolder $FileName

    $Data |
        ConvertTo-Json -Depth 10 |
        Set-Content $file -Encoding UTF8
}

function Backup-Configuration {

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    $backupPath = Join-Path `
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