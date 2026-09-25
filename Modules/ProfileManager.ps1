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
        [string]$Folder
    )

    $projects = Get-Projects

    $newProject = [PSCustomObject]@{
        name = $Name
        environment = $Environment
        user = $User
        solution = $Solution
        folder = $Folder
        startupApps = @(
            "SSMS",
            "VisualStudio",
            "VSCode"
        )
    }

    $projects.projects += $newProject

    Save-Projects $projects
}