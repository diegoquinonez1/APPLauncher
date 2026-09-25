function Start-ProjectProfile {

    param(
        [string]$ProjectName
    )

    $projects = Get-Projects

    $project =
        $projects.projects |
        Where-Object {
            $_.name -eq $ProjectName
        } |
        Select-Object -First 1

    if(!$project){

        throw "Perfil no encontrado."
    }

    foreach($app in $project.startupApps){

        Start-AONApplication `
            $app `
            $project.environment `
            $project.user

        Start-Sleep -Seconds 2
    }

    if(
        $project.solution -and
        (Test-Path $project.solution)
    ){

        Start-Process $project.solution
    }

    if(
        $project.folder -and
        (Test-Path $project.folder)
    ){

        explorer.exe $project.folder
    }
}