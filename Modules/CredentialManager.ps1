function Get-EnvironmentDomain {

    param(
        [string]$Environment
    )

    switch($Environment){

        "DEV" {
            return "devaonnet"
        }

        "QC" {
            return "extadqc"
        }

        "PROD" {
            return "extad"
        }
    }
}

function Get-CredentialTarget {

    param(
        [string]$Environment,
        [string]$User
    )

    return "AON_{0}_{1}" -f `
        $Environment,
        $User
}

function Add-LauncherCredential {

    param(
        [string]$Environment,
        [string]$User,
        [string]$Password
    )

    $domain = Get-EnvironmentDomain $Environment

    $target = Get-CredentialTarget `
        $Environment `
        $User

    cmdkey `
        /add:$target `
        /user:$domain\$User `
        /pass:$Password
}

function Remove-LauncherCredential {

    param(
        [string]$Environment,
        [string]$User
    )

    $target = Get-CredentialTarget `
        $Environment `
        $User

    cmdkey `
        /delete:$target
}

function Test-LauncherCredential {

    param(
        [string]$Environment,
        [string]$User
    )

    $target = Get-CredentialTarget `
        $Environment `
        $User

    $result = cmdkey /list

    return (
        $result |
        Select-String $target
    ) -ne $null
}

function Get-LauncherCredentials {

    cmdkey /list
}