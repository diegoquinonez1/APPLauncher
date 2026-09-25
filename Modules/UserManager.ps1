function Get-Users {

    return Get-JsonFile "users.json"
}

function Save-Users {

    param($Users)

    Save-JsonFile `
        "users.json" `
        $Users
}

function Add-LauncherUser {

    param(
        [string]$UserName
    )

    $config = Get-Users

    if($config.users -contains $UserName){

        throw "El usuario ya existe."
    }

    $config.users += $UserName

    Save-Users $config
}

function Remove-LauncherUser {

    param(
        [string]$UserName
    )

    $config = Get-Users

    if($UserName -eq $config.defaultUser){

        throw "El usuario predeterminado no puede eliminarse."
    }

    $config.users =
        @(
            $config.users |
            Where-Object {
                $_ -ne $UserName
            }
        )

    Save-Users $config
}

function Update-LauncherUser {

    param(
        [string]$OldUser,
        [string]$NewUser
    )

    $config = Get-Users

    if($OldUser -eq $config.defaultUser){

        throw "El usuario predeterminado no puede modificarse."
    }

    if($config.users -contains $NewUser){

        throw "El usuario destino ya existe."
    }

    $newList = @()

    foreach($user in $config.users){

        if($user -eq $OldUser){
            $newList += $NewUser
        }
        else{
            $newList += $user
        }
    }

    $config.users = $newList

    Save-Users $config
}