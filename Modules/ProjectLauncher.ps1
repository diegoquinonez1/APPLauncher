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

    $matchingProjects = @(
        (Get-Projects).projects |
        Where-Object {
            $null -ne $_ -and
            $_.name -eq $Project.name
        }
    )

    if($matchingProjects.Count -gt 1){
        throw "Hay varios perfiles con el nombre '$($Project.name)'."
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

        [void](Get-DomainByEnvironment $Project.environment)

        $configuredApplications = Get-Applications
        foreach($app in $startupApps){

            switch($app){
                "SSMS" { $applicationPath = $configuredApplications.SSMS }
                "VisualStudio" { $applicationPath = $configuredApplications.VisualStudio }
                "VSCode" { $applicationPath = $configuredApplications.VSCode }
                "ReportBuilder" { $applicationPath = $configuredApplications.ReportBuilder }
                default { throw "Aplicación no soportada: $app" }
            }

            if([string]::IsNullOrWhiteSpace([string]$applicationPath)){
                throw "Ruta no encontrada para $app"
            }

            if(!(Test-Path -LiteralPath $applicationPath -PathType Leaf)){
                throw "No existe el ejecutable: $applicationPath"
            }
        }

    }

    if(
        -not [string]::IsNullOrWhiteSpace($solutionPath) -and
        !(Test-Path -LiteralPath $solutionPath -PathType Leaf)
    ){
        throw "No existe la solución del perfil '$($Project.name)': $solutionPath"
    }

    if(
        -not [string]::IsNullOrWhiteSpace($folderPath) -and
        !(Test-Path -LiteralPath $folderPath -PathType Container)
    ){
        throw "No existe la carpeta del perfil '$($Project.name)': $folderPath"
    }

    foreach($app in $startupApps){

        Start-AppLauncherApplication `
            $app `
            $Project.environment `
            $Project.user

        Start-Sleep -Seconds 2
    }

    if(-not [string]::IsNullOrWhiteSpace($solutionPath)){
        Start-Process $solutionPath
    }

    if(-not [string]::IsNullOrWhiteSpace($folderPath)){
        Start-Process explorer.exe -ArgumentList "`"$folderPath`""
    }

    Write-ProjectLog `
        $Project.environment `
        $Project.user `
        $Project.name
}