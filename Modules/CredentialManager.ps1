if(-not (Get-Command Test-CyberArkIntegrationEnabled -ErrorAction SilentlyContinue)){
    $cyberArkProviderPath = Join-Path $PSScriptRoot "CyberArkProvider.ps1"
    if(Test-Path $cyberArkProviderPath){
        . $cyberArkProviderPath
    }
}

$script:ExpiredLauncherCredentialStatuses = @()

function Get-Credentials {

    Get-JsonFile "credentials.json"

}

function Get-CredentialExpiryInfo {

    param(
        $Credential,
        [datetime]$Now = (Get-Date)
    )

    $updatedAt = [datetime]::MinValue
    $hasValidTimestamp =
        $null -ne $Credential.updatedAt -and
        [datetime]::TryParse(
            [string]$Credential.updatedAt,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AssumeLocal,
            [ref]$updatedAt
        )

    if(!$hasValidTimestamp){

        return [PSCustomObject]@{
            Status = "Expirada"
            ExpiresAt = $null
            Remaining = [timespan]::Zero
        }

    }

    $expiresAt = $updatedAt.AddHours(8)
    $remaining = $expiresAt - $Now
    $status = "Válida"

    if($remaining -le [timespan]::Zero){

        $status = "Expirada"

    }
    elseif($remaining -le [timespan]::FromHours(1)){

        $status = "Próxima a expirar"

    }

    return [PSCustomObject]@{
        Status = $status
        ExpiresAt = $expiresAt
        Remaining = $remaining
    }

}

function Get-LauncherCredentialStatus {

    param(
        [string]$Environment,
        [string]$User
    )

    $settings = Get-CyberArkSettings
    $store = Get-Credentials
    $credential =
        $store.credentials |
        Where-Object {

            $_.environment -eq $Environment -and
            $_.user -eq $User

        } |
        Select-Object -First 1

    if(Test-CyberArkIntegrationEnabled){
        $hasServiceCredentials = -not [string]::IsNullOrWhiteSpace([string]$settings.username) -or
            -not [string]::IsNullOrWhiteSpace([string]$settings.password) -or
            -not [string]::IsNullOrWhiteSpace([string]$settings.appId)

        try{
            $vaultPassword = Get-CyberArkCredentialValue -Environment $Environment -User $User
            if(-not [string]::IsNullOrWhiteSpace([string]$vaultPassword)){
                Save-LauncherCredential -Environment $Environment -User $User -Password $vaultPassword
                return [PSCustomObject]@{
                    Environment = $Environment
                    User = $User
                    Status = "Válida"
                    ExpiresAt = (Get-Date).AddHours(8)
                    Remaining = [timespan]::FromHours(8)
                }
            }
        }
        catch{
        }
    }

    if($credential){
        $expiryInfo = Get-CredentialExpiryInfo $credential

        return [PSCustomObject]@{
            Environment = $Environment
            User = $User
            Status = $expiryInfo.Status
            ExpiresAt = $expiryInfo.ExpiresAt
            Remaining = $expiryInfo.Remaining
        }
    }

    if(Test-CyberArkIntegrationEnabled){
        $hasServiceCredentials = -not [string]::IsNullOrWhiteSpace([string]$settings.username) -or
            -not [string]::IsNullOrWhiteSpace([string]$settings.password) -or
            -not [string]::IsNullOrWhiteSpace([string]$settings.appId)

        if(-not $hasServiceCredentials -and $settings.PSObject.Properties.Name -contains "interactiveLogin" -and [bool]$settings.interactiveLogin){
            return [PSCustomObject]@{
                Environment = $Environment
                User = $User
                Status = "Login interactivo requerido: CyberArk/Okta abrió sesión, pero no se obtuvo contraseña"
                ExpiresAt = $null
                Remaining = [timespan]::Zero
            }
        }
    }

    $expiredStatus =
        $script:ExpiredLauncherCredentialStatuses |
        Where-Object {

            $_.Environment -eq $Environment -and
            $_.User -eq $User

        } |
        Select-Object -First 1

    if($expiredStatus){

        return [PSCustomObject]@{
            Environment = $Environment
            User = $User
            Status = "Expirada"
            ExpiresAt = $expiredStatus.ExpiresAt
            Remaining = [timespan]::Zero
        }

    }

    return [PSCustomObject]@{
        Environment = $Environment
        User = $User
        Status = "No configurada"
        ExpiresAt = $null
        Remaining = [timespan]::Zero
    }

}

function Remove-ExpiredLauncherCredentials {

    $store = Get-Credentials
    $now = Get-Date
    $activeCredentials = @()
    $removedCount = 0

    foreach($credential in @($store.credentials)){

        $expiryInfo = Get-CredentialExpiryInfo $credential $now

        if($expiryInfo.Status -eq "Expirada"){

            $removedCount++
            $script:ExpiredLauncherCredentialStatuses = @(
                $script:ExpiredLauncherCredentialStatuses |
                Where-Object {

                    $_.Environment -ne $credential.environment -or
                    $_.User -ne $credential.user

                }
            )
            $script:ExpiredLauncherCredentialStatuses +=
                [PSCustomObject]@{
                    Environment = $credential.environment
                    User = $credential.user
                    ExpiresAt = $expiryInfo.ExpiresAt
                }

        }
        else{

            $activeCredentials += $credential

        }

    }

    if($removedCount -gt 0){

        $store.credentials = $activeCredentials
        Save-Credentials $store

    }

    return $removedCount

}

function Save-Credentials {

    param($Data)

    Save-JsonFile `
        "credentials.json" `
        $Data

}

function Protect-Password {

    param(
        [string]$Password
    )

    $secure =
        ConvertTo-SecureString `
            $Password `
            -AsPlainText `
            -Force

    return $secure |
        ConvertFrom-SecureString

}

function Unprotect-Password {

    param(
        [string]$EncryptedPassword
    )

    $secure =
        ConvertTo-SecureString `
            $EncryptedPassword

    $ptr =
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            $secure
        )

    try {

        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            $ptr
        )

    }
    finally {

        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
            $ptr
        )

    }

}

function Save-LauncherCredential {

    param(
        [string]$Environment,
        [string]$User,
        [string]$Password
    )

    Remove-ExpiredLauncherCredentials | Out-Null
    $script:ExpiredLauncherCredentialStatuses = @(
        $script:ExpiredLauncherCredentialStatuses |
        Where-Object {

            $_.Environment -ne $Environment -or
            $_.User -ne $User

        }
    )
    $store = Get-Credentials

    $existing =
        $store.credentials |
        Where-Object {

            $_.environment -eq $Environment -and
            $_.user -eq $User

        }

    if($existing){

        $existing.password =
            Protect-Password $Password

        $existing.updatedAt =
            (Get-Date).ToString("s")

    }
    else{

        $store.credentials +=
            [PSCustomObject]@{

                environment =
                    $Environment

                user =
                    $User

                password =
                    (Protect-Password $Password)

                updatedAt =
                    (Get-Date).ToString("s")

            }

    }

    Save-Credentials $store

}

function Remove-LauncherCredential {

    param(
        [string]$Environment,
        [string]$User
    )

    $store = Get-Credentials
    $script:ExpiredLauncherCredentialStatuses = @(
        $script:ExpiredLauncherCredentialStatuses |
        Where-Object {

            $_.Environment -ne $Environment -or
            $_.User -ne $User

        }
    )

    $store.credentials =
        @(
            $store.credentials |
            Where-Object {

                !(
                    $_.environment -eq $Environment -and
                    $_.user -eq $User
                )

            }
        )

    Save-Credentials $store

}

function Test-LauncherCredential {

    param(
        [string]$Environment,
        [string]$User
    )

    if(Test-CyberArkIntegrationEnabled){
        try{
            $vaultPassword = Get-CyberArkCredentialValue -Environment $Environment -User $User
            if(-not [string]::IsNullOrWhiteSpace([string]$vaultPassword)){
                Save-LauncherCredential -Environment $Environment -User $User -Password $vaultPassword
                return $true
            }
        }
        catch{
        }
    }

    $status = Get-LauncherCredentialStatus $Environment $User

    if($status.Status -eq "Expirada"){

        Remove-ExpiredLauncherCredentials | Out-Null
        return $false

    }

    if($status.Status -match "login interactivo|CyberArk|manual"){
        return $false
    }

    return $status.Status -ne "No configurada"

}

function Get-LauncherCredential {

    param(
        [string]$Environment,
        [string]$User
    )

    if(Test-CyberArkIntegrationEnabled){
        try{
            $vaultPassword = Get-CyberArkCredentialValue -Environment $Environment -User $User
            if(-not [string]::IsNullOrWhiteSpace([string]$vaultPassword)){
                Save-LauncherCredential -Environment $Environment -User $User -Password $vaultPassword
                return [PSCustomObject]@{
                    Environment = $Environment
                    User = $User
                    Password = $vaultPassword
                }
            }
        }
        catch{
        }
    }

    $status = Get-LauncherCredentialStatus $Environment $User

    if($status.Status -eq "Expirada"){

        Remove-ExpiredLauncherCredentials | Out-Null
        return $null

    }

    if($status.Status -eq "No configurada"){

        return $null

    }

    if($status.Status -match "login interactivo|CyberArk|manual"){
        return $null
    }

    $store = Get-Credentials

    $cred =
        $store.credentials |
        Where-Object {

            $_.environment -eq $Environment -and
            $_.user -eq $User

        } |
        Select-Object -First 1

    if(!$cred){

        return $null

    }

    return [PSCustomObject]@{

        Environment =
            $Environment

        User =
            $User

        Password =
            (Unprotect-Password $cred.password)

    }

}

function Copy-LauncherCredentialToClipboard {

    param(
        [string]$Environment,
        [string]$User
    )

    $status = Get-LauncherCredentialStatus $Environment $User

    if($status.Status -eq "Expirada"){

        Remove-ExpiredLauncherCredentials | Out-Null
        throw "La credencial para el usuario y entorno seleccionados expiró y fue eliminada."

    }

    $credential =
        Get-LauncherCredential `
            $Environment `
            $User

    if(!$credential){

        $status = Get-LauncherCredentialStatus $Environment $User

        if($status.Status -eq "Expirada"){

            Remove-ExpiredLauncherCredentials | Out-Null
            throw "La credencial para el usuario y entorno seleccionados expiró y fue eliminada."

        }

        if($status.Status -match "login interactivo|CyberArk|manual"){
            throw "CyberArk/Okta requiere login interactivo y aún no se recuperó una contraseña válida."
        }

        throw "No existe una credencial configurada para el usuario y entorno seleccionados."

    }

    [System.Windows.Forms.Clipboard]::SetText(
        $credential.Password
    )

}