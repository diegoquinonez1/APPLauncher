function Get-DomainByEnvironment {

    param(
        [string]$Environment
    )

    switch($Environment){

        "DEV"  { return "devaonnet" }
        "QC"   { return "extadqc" }
        "PROD" { return "extad" }

        default {
            throw "Entorno no soportado."
        }
    }
}

function Start-AONApplication {

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