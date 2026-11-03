[CmdletBinding()]
param(
    [string[]]$Path = @((Join-Path $PSScriptRoot "*.Tests.ps1"))
)

$requiredPesterVersion = [version]'3.4.0'
$pester = Get-Module -ListAvailable Pester |
    Where-Object { $_.Version -eq $requiredPesterVersion } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if($null -eq $pester){
    throw "Pester $requiredPesterVersion no está instalado. Instálelo con: Install-Module Pester -RequiredVersion 3.4.0 -Scope CurrentUser"
}

$scriptFiles = @()
foreach($pattern in $Path){
    $scriptFiles += @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue)
}
$scriptFiles = @($scriptFiles | Sort-Object FullName -Unique)

if($scriptFiles.Count -eq 0){
    throw "No se encontraron archivos *.Tests.ps1 para ejecutar."
}

Import-Module Pester -RequiredVersion $requiredPesterVersion -Force
try{
    $result = Invoke-Pester -Path $scriptFiles.FullName -PassThru
}
finally{
    Remove-Item -Path Function:\global:Get-APPLauncherFormControls -ErrorAction SilentlyContinue
}

if($result.FailedCount -gt 0){
    exit 1
}
