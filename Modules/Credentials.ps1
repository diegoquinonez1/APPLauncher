if(-not (Get-Command -Name Get-LauncherEnvironmentDomain -ErrorAction SilentlyContinue)){
    $moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    . (Join-Path $moduleRoot "ConfigManager.ps1")
}

function Get-DomainByEnvironment {

    param($Environment)

    $domain = Get-LauncherEnvironmentDomain -Environment $Environment
    if(-not [string]::IsNullOrWhiteSpace($domain)){
        return $domain
    }

    throw "El entorno '$Environment' no está configurado en el archivo de ambientes."
}

function Add-Credential {

    param(
        $Environment,
        $User,
        [string]$SecretValue
    )

    $domain = Get-DomainByEnvironment $Environment

    $target = "AON_{0}_{1}" -f $Environment,$User

    cmdkey `
      /add:$target `
      /user:$domain\$User `
      /pass:$SecretValue
}

function Remove-Credential {

    param(
        $Environment,
        $User
    )

    $target = "AON_{0}_{1}" -f $Environment,$User

    cmdkey /delete:$target
}