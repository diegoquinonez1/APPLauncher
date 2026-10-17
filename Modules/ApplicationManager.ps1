function Get-Applications {

    Get-JsonFile "applications.json"
}

function Save-Applications {

    param($Apps)

    Save-JsonFile `
        "applications.json" `
        $Apps
}

function Find-SSMS {

    $paths = @(
        "C:\Program Files\Microsoft SQL Server Management Studio*",
        "C:\Program Files (x86)\Microsoft SQL Server Management Studio*"
    )

    foreach($path in $paths){

        $found = Get-ChildItem `
            -Path $path `
            -Filter "SSMS.exe" `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if($found){
            return $found.FullName
        }
    }

    return ""
}

function Find-VisualStudio {

    $found = Get-ChildItem `
        "C:\Program Files\Microsoft Visual Studio" `
        -Filter devenv.exe `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if($found){
        return $found.FullName
    }

    return ""
}

function Find-VSCode {

    $paths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code",
        "C:\Program Files\Microsoft VS Code"
    )

    foreach($path in $paths){

        $exe = Join-Path $path "Code.exe"

        if(Test-Path $exe){
            return $exe
        }
    }

    return ""
}

function Find-ReportBuilder {

    $found = Get-ChildItem `
        "C:\Program Files" `
        -Filter MSReportBuilder.exe `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if($found){
        return $found.FullName
    }

    return ""
}

function Scan-Applications {

    $apps = Get-Applications

    $apps.SSMS = Find-SSMS
    $apps.VisualStudio = Find-VisualStudio
    $apps.VSCode = Find-VSCode
    $apps.ReportBuilder = Find-ReportBuilder

    $apps.LastScan = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Save-Applications $apps

    return $apps
}