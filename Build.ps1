$ErrorActionPreference = "Stop"

$sourcePath = Join-Path $PSScriptRoot "Launcher.ps1"
$outputPath = Join-Path $PSScriptRoot "APPLauncher.exe"
$iconPath = Join-Path $PSScriptRoot "Assets\favicon.ico"

foreach($requiredPath in @($sourcePath, $iconPath)){
    if(!(Test-Path -LiteralPath $requiredPath -PathType Leaf)){
        throw "No se encontró el archivo requerido: $requiredPath"
    }
}

if(!(Get-Module -ListAvailable -Name ps2exe)){
    Install-Module ps2exe -Scope CurrentUser -Force
}

Import-Module ps2exe -ErrorAction Stop
$converter = Get-Command Invoke-PS2EXE -ErrorAction Stop
if(-not $converter.Parameters.ContainsKey("iconFile")){
    throw "La versión instalada de ps2exe no admite el parámetro iconFile."
}

Invoke-PS2EXE `
    -inputFile $sourcePath `
    -outputFile $outputPath `
    -iconFile $iconPath `
    -noConsole

if(!(Test-Path -LiteralPath $outputPath -PathType Leaf)){
    throw "ps2exe no generó el archivo esperado: $outputPath"
}

Get-Item -LiteralPath $outputPath | Select-Object FullName, Length, LastWriteTime