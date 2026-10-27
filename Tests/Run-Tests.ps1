[CmdletBinding()]
param(
    [string[]]$Path = @((Join-Path $PSScriptRoot "*.Tests.ps1"))
)

$pester = Get-Module -ListAvailable Pester |
    Sort-Object Version -Descending |
    Select-Object -First 1

if($null -eq $pester){
    throw "Pester no está instalado. Instálelo con: Install-Module Pester -Scope CurrentUser"
}

$scriptFiles = @()
foreach($pattern in $Path){
    $scriptFiles += @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue)
}
$scriptFiles = @($scriptFiles | Sort-Object FullName -Unique)

if($scriptFiles.Count -eq 0){
    throw "No se encontraron archivos *.Tests.ps1 para ejecutar."
}

Import-Module Pester -RequiredVersion $pester.Version -Force
try{
    $result = Invoke-Pester -Script $scriptFiles.FullName -PassThru
}
finally{
    Remove-Item -Path Function:\global:Get-APPLauncherFormControls -ErrorAction SilentlyContinue
}

if($result.FailedCount -gt 0){
    exit 1
}
