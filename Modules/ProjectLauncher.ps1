function Start-ProjectProfile {

    param(
        [string]$ProjectName,
        [psobject]$Project
    )

    if($null -eq $Project){

        if([string]::IsNullOrWhiteSpace($ProjectName)){
            throw "Debe especificar un proyecto."
        }

        $matches = @(
            (Get-Projects).projects |
            Where-Object {
                $_.name -eq $ProjectName
            }
        )

        if($matches.Count -eq 0){
            throw "Perfil no encontrado: $ProjectName"
        }

        if($matches.Count -gt 1){
            throw "Hay varios perfiles con el nombre '$ProjectName'."
        }

        $Project = $matches[0]
    }

    if([string]::IsNullOrWhiteSpace([string]$Project.name)){
        throw "El perfil no tiene nombre."
    }

    $startupApps = @(
        $Project.startupApps |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        }
    )

    $solutionPath = [string]$Project.solution
    $folderPath = [string]$Project.folder

    if(
        $startupApps.Count -eq 0 -and
        [string]::IsNullOrWhiteSpace($solutionPath) -and
        [string]::IsNullOrWhiteSpace($folderPath)
    ){
        throw "El perfil '$($Project.name)' no tiene aplicaciones, solución ni carpeta configuradas."
    }

    if($startupApps.Count -gt 0){

        if([string]::IsNullOrWhiteSpace([string]$Project.environment)){
            throw "El perfil '$($Project.name)' no tiene un entorno configurado."
        }

        if([string]::IsNullOrWhiteSpace([string]$Project.user)){
            throw "El perfil '$($Project.name)' no tiene un usuario configurado."
        }

    }

    foreach($app in $startupApps){

        Start-AONApplication `
            $app `
            $Project.environment `
            $Project.user

        Start-Sleep -Seconds 2
    }

    if(-not [string]::IsNullOrWhiteSpace($solutionPath)){

        if(!(Test-Path $solutionPath)){
            throw "No existe la solución del perfil '$($Project.name)': $solutionPath"
        }

        Start-Process $solutionPath
    }

    if(-not [string]::IsNullOrWhiteSpace($folderPath)){

        if(!(Test-Path $folderPath)){
            throw "No existe la carpeta del perfil '$($Project.name)': $folderPath"
        }

        Start-Process explorer.exe -ArgumentList "`"$folderPath`""
    }

    Write-ProjectLog `
        $Project.environment `
        $Project.user `
        $Project.name
}