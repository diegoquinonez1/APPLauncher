function Get-Favorites {

    Get-JsonFile "favorites.json"
}

function Save-Favorites {

    param($Favorites)

    Save-JsonFile `
        "favorites.json" `
        $Favorites
}

function Add-Favorite {

    param(
        [string]$Name,
        [string]$User,
        [string]$Environment,
        [string]$Application
    )

    $favorites = Get-Favorites

    $newFavorite = [PSCustomObject]@{

        Name = $Name
        User = $User
        Environment = $Environment
        Application = $Application
    }

    $favorites.favorites += $newFavorite

    Save-Favorites $favorites
}

function Remove-Favorite {

    param(
        [string]$Name
    )

    $favorites = Get-Favorites

    $favorites.favorites =
        @(
            $favorites.favorites |
            Where-Object {

                $_.Name -ne $Name
            }
        )

    Save-Favorites $favorites
}