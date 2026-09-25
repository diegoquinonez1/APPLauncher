function Get-Credentials {

    Get-JsonFile "credentials.json"

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

    $store = Get-Credentials

    return $null -ne (
        $store.credentials |
        Where-Object {

            $_.environment -eq $Environment -and
            $_.user -eq $User

        } |
        Select-Object -First 1
    )

}

function Get-LauncherCredential {

    param(
        [string]$Environment,
        [string]$User
    )

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

    $credential =
        Get-LauncherCredential `
            $Environment `
            $User

    if(!$credential){

        throw "No existe una credencial configurada para el usuario y entorno seleccionados."

    }

    [System.Windows.Forms.Clipboard]::SetText(
        $credential.Password
    )

}