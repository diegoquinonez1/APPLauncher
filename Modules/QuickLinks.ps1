function ConvertTo-QuickLink {

    param(
        [object]$Link
    )

    $name = [string]$Link.name
    $url = [string]$Link.url

    if([string]::IsNullOrWhiteSpace($name)){
        throw "El nombre del acceso es obligatorio."
    }

    $name = $name.Trim()
    $url = $url.Trim()

    if([string]::IsNullOrWhiteSpace($url)){
        throw "La URL de '$name' es obligatoria."
    }

    $parsedUrl = $null
    if(-not [System.Uri]::TryCreate(
        $url,
        [System.UriKind]::Absolute,
        [ref]$parsedUrl
    )){
        throw "La URL de '$name' no es válida."
    }

    if(
        $parsedUrl.Scheme -notin @("http", "https") -or
        [string]::IsNullOrWhiteSpace($parsedUrl.Host) -or
        -not [string]::IsNullOrWhiteSpace($parsedUrl.UserInfo)
    ){
        throw "La URL de '$name' debe usar HTTP o HTTPS y no incluir credenciales."
    }

    return [PSCustomObject]@{
        name = $name
        url = $parsedUrl.AbsoluteUri
    }
}

function Get-QuickLinks {

    $configuration = Get-JsonFile "links.json"

    if($null -eq $configuration.links){
        return @()
    }

    return @($configuration.links)
}

function Save-QuickLinks {

    param(
        [object[]]$Links
    )

    $validatedLinks = @()
    $names = @{}

    foreach($link in @($Links)){

        $validatedLink = ConvertTo-QuickLink $link

        if($names.ContainsKey($validatedLink.name)){
            throw "Ya existe un acceso llamado '$($validatedLink.name)'."
        }

        $names[$validatedLink.name] = $true
        $validatedLinks += $validatedLink
    }

    Save-JsonFile `
        "links.json" `
        @{ links = @($validatedLinks) }
}

function Open-QuickLink {

    param(
        [object]$Link
    )

    $validatedLink = ConvertTo-QuickLink $Link
    Start-Process -FilePath $validatedLink.url
}