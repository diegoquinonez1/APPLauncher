$Global:LogFile = Join-Path `
    $PSScriptRoot `
    "..\Logs\launcher.log"

function Write-LauncherLog {

    param(
        [string]$Environment,
        [string]$User,
        [string]$Application
    )

    $line =
        "{0} | INFO | {1} | {2} | {3}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        $Environment,
        $User,
        $Application

    Add-Content `
        -Path $Global:LogFile `
        -Value $line

}

function Write-ProjectLog {

    param(
        [string]$Environment,
        [string]$User,
        [string]$Project
    )

    $safeEnvironment = $Environment
    if([string]::IsNullOrWhiteSpace($safeEnvironment)){
        $safeEnvironment = "-"
    }

    $safeUser = $User
    if([string]::IsNullOrWhiteSpace($safeUser)){
        $safeUser = "-"
    }

    $safeProject = $Project -replace '\|', '/'
    $line =
        "{0} | PROJECT | {1} | {2} | {3}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        $safeEnvironment,
        $safeUser,
        $safeProject

    Add-Content `
        -Path $Global:LogFile `
        -Value $line

}

function Get-LauncherDashboardMetrics {

    param(
        [datetime]$Now = (Get-Date),
        [string]$LogPath = $Global:LogFile
    )

    $applicationCounts = @{}
    $projectCounts = @{}
    $latestApplication = $null
    $latestProject = $null
    $executionsToday = 0
    $executionsThisMonth = 0

    if(Test-Path $LogPath){

        $logLines = Get-Content -Path $LogPath -ErrorAction SilentlyContinue

        foreach($line in $logLines){

            $parts = $line -split '\s+\|\s+', 5
            if($parts.Count -ne 5){
                continue
            }

            $timestamp = [datetime]::MinValue
            $parsed = [datetime]::TryParseExact(
                $parts[0],
                "yyyy-MM-dd HH:mm:ss",
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::None,
                [ref]$timestamp
            )

            if(-not $parsed){
                continue
            }

            if($parts[1] -eq "INFO"){

                $application = $parts[4].Trim()
                if([string]::IsNullOrWhiteSpace($application)){
                    continue
                }

                if(-not $applicationCounts.ContainsKey($application)){
                    $applicationCounts[$application] = 0
                }
                $applicationCounts[$application]++

                if($null -eq $latestApplication -or $timestamp -ge $latestApplication.Timestamp){
                    $latestApplication = [pscustomobject]@{
                        Name = $application
                        Timestamp = $timestamp
                    }
                }

                if($timestamp.Date -eq $Now.Date){
                    $executionsToday++
                }

                if(
                    $timestamp.Year -eq $Now.Year -and
                    $timestamp.Month -eq $Now.Month
                ){
                    $executionsThisMonth++
                }

                continue
            }

            if($parts[1] -eq "PROJECT"){

                $project = $parts[4].Trim()
                if([string]::IsNullOrWhiteSpace($project)){
                    continue
                }

                if(-not $projectCounts.ContainsKey($project)){
                    $projectCounts[$project] = 0
                }
                $projectCounts[$project]++

                if($null -eq $latestProject -or $timestamp -ge $latestProject.Timestamp){
                    $latestProject = [pscustomobject]@{
                        Name = $project
                        Timestamp = $timestamp
                    }
                }
            }
        }
    }

    $mostUsedApplication = $null
    foreach($application in @($applicationCounts.Keys | Sort-Object)){
        if(
            $null -eq $mostUsedApplication -or
            $applicationCounts[$application] -gt $mostUsedApplication.Count
        ){
            $mostUsedApplication = [pscustomobject]@{
                Name = $application
                Count = $applicationCounts[$application]
            }
        }
    }

    $mostUsedProject = $null
    foreach($project in @($projectCounts.Keys | Sort-Object)){
        if(
            $null -eq $mostUsedProject -or
            $projectCounts[$project] -gt $mostUsedProject.Count
        ){
            $mostUsedProject = [pscustomobject]@{
                Name = $project
                Count = $projectCounts[$project]
            }
        }
    }

    return [pscustomobject]@{
        LatestApplication = $latestApplication
        LatestProject = $latestProject
        MostUsedApplication = $mostUsedApplication
        MostUsedProject = $mostUsedProject
        ExecutionsToday = $executionsToday
        ExecutionsThisMonth = $executionsThisMonth
    }

}

function Write-ErrorLog {

    param(
        [string]$Message
    )

    $line =
        "{0} | ERROR | {1}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        $Message

    Add-Content `
        -Path $Global:LogFile `
        -Value $line

}

function Get-LauncherLogs {

    if(!(Test-Path $Global:LogFile)){

        return @()

    }

    return Get-Content $Global:LogFile

}

function Clear-LauncherLogs {

    "" | Set-Content $Global:LogFile

}