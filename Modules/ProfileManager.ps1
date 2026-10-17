function Get-Projects {

    Get-JsonFile "projects.json"
}

function Save-Projects {

    param($Projects)

    Save-JsonFile `
        "projects.json" `
        $Projects
}

function Add-Project {

    param(
        [string]$Name,
        [string]$Environment,
        [string]$User,
        [string]$Solution,
        [string]$Folder,
        [string[]]$StartupApps = @(
            "SSMS",
            "VisualStudio",
            "VSCode"
        )
    )

    $projects = Get-Projects

    if($null -eq $projects.projects){
        $projects.projects = @()
    }

    if(
        $projects.projects |
        Where-Object {
            $_.name -eq $Name
        }
    ){
        throw "Ya existe un proyecto con el nombre '$Name'."
    }

    $newProject = [PSCustomObject]@{
        name = $Name
        environment = $Environment
        user = $User
        solution = $Solution
        folder = $Folder
        startupApps = @(
            $StartupApps |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
        )
    }

    $projects.projects += $newProject

    Save-Projects $projects
}

function Update-Project {

    param(
        [string]$OriginalName,
        [string]$Name,
        [string]$Environment,
        [string]$User,
        [string]$Solution,
        [string]$Folder,
        [string[]]$StartupApps
    )

    $projects = Get-Projects

    if($null -eq $projects.projects){
        $projects.projects = @()
    }

    $existing = @(
        $projects.projects |
        Where-Object {
            $_.name -eq $OriginalName
        }
    )

    if($existing.Count -eq 0){
        throw "Proyecto no encontrado: $OriginalName"
    }

    if(
        $OriginalName -ne $Name -and
        ($projects.projects |
            Where-Object {
                $_.name -eq $Name
            }).Count -gt 0
    ){
        throw "Ya existe un proyecto con el nombre '$Name'."
    }

    $updatedProjects = @()

    foreach($project in $projects.projects){

        if($project.name -eq $OriginalName){

            $updatedProjects += [PSCustomObject]@{
                name = $Name
                environment = $Environment
                user = $User
                solution = $Solution
                folder = $Folder
                startupApps = @(
                    $StartupApps |
                    Where-Object {
                        -not [string]::IsNullOrWhiteSpace($_)
                    }
                )
            }
        }
        else{
            $updatedProjects += $project
        }
    }

    $projects.projects = $updatedProjects

    Save-Projects $projects
}

function Remove-Project {

    param(
        [string]$Name
    )

    $projects = Get-Projects

    $projects.projects = @(
        $projects.projects |
        Where-Object {
            $_.name -ne $Name
        }
    )

    Save-Projects $projects
}