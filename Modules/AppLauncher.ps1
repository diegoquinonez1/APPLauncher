if(-not (Get-Command -Name Get-LauncherEnvironmentDomain -ErrorAction SilentlyContinue)){
    $moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    . (Join-Path $moduleRoot "ConfigManager.ps1")
}

function Get-DomainByEnvironment {

    param(
        [string]$Environment
    )

    $domain = Get-LauncherEnvironmentDomain -Environment $Environment
    if(-not [string]::IsNullOrWhiteSpace($domain)){
        return $domain
    }

    throw "El entorno '$Environment' no está configurado en el archivo de ambientes."
}

function Start-AppLauncherApplication {

    param(
        [string]$ApplicationName,
        [string]$Environment,
        [string]$User
    )

    $apps = Get-Applications

    switch($ApplicationName){

        "SSMS" {
            $exe = $apps.SSMS
        }

        "VisualStudio" {
            $exe = $apps.VisualStudio
        }

        "VSCode" {
            $exe = $apps.VSCode
        }

        "ReportBuilder" {
            $exe = $apps.ReportBuilder
        }

        default {

            throw "Aplicación no soportada."
        }
    }

    if([string]::IsNullOrWhiteSpace($exe)){
        throw "Ruta no encontrada para $ApplicationName"
    }

    if(!(Test-Path $exe)){
        throw "No existe el ejecutable: $exe"
    }

    $domain =
        Get-DomainByEnvironment $Environment

    $arguments =
        "/netonly /noprofile /env /user:$domain\$User `"$exe`""

    Start-Process `
        runas.exe `
        -ArgumentList $arguments

    Write-LauncherLog `
        $Environment `
        "$domain\$User" `
        $ApplicationName
}