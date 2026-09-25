function Get-Users {

    $file = Join-Path $PSScriptRoot "..\Config\users.json"

    return Get-Content $file -Raw | ConvertFrom-Json
}

function Save-Users($data){

    $file = Join-Path $PSScriptRoot "..\Config\users.json"

    $data | ConvertTo-Json -Depth 10 |
        Set-Content $file
}

function Add-LauncherUser($user){

    $users = Get-Users

    if($users.users -contains $user){
        return
    }

    $users.users += $user

    Save-Users $users
}

function Remove-LauncherUser($user){

    $users = Get-Users

    if($user -eq $users.defaultUser){
        throw "El usuario predeterminado no puede eliminarse."
    }

    $users.users = @(
        $users.users |
        Where-Object { $_ -ne $user }
    )

    Save-Users $users
}

function Update-LauncherUser($oldUser,$newUser){

    $users = Get-Users

    if($oldUser -eq $users.defaultUser){
        throw "El usuario predeterminado no puede modificarse."
    }

    $users.users =
        $users.users |
        ForEach-Object {

            if($_ -eq $oldUser){
                $newUser
            }
            else{
                $_
            }
        }

    Save-Users $users
}