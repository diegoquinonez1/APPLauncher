$script:AONTestRepositoryRoot = Split-Path -Parent $PSScriptRoot

if(-not ("AONLauncherTestControlWalker" -as [type])){
    Add-Type -TypeDefinition @"
using System.Collections;
using System.Collections.Generic;
using System.Reflection;

public static class AONLauncherTestControlWalker
{
    public static object[] GetDescendants(object root)
    {
        var result = new List<object>();
        var pending = new Queue<object>();
        var controlsProperty = root.GetType().GetProperty("Controls");
        var rootControls = controlsProperty.GetValue(root, null) as IEnumerable;
        foreach (var control in rootControls)
        {
            pending.Enqueue(control);
        }

        while (pending.Count > 0)
        {
            var control = pending.Dequeue();
            result.Add(control);
            var property = control.GetType().GetProperty("Controls");
            var children = property.GetValue(control, null) as IEnumerable;
            foreach (var child in children)
            {
                pending.Enqueue(child);
            }
        }

        return result.ToArray();
    }
}
"@
}

function New-AONTestRoot {

    $root = Join-Path ([IO.Path]::GetTempPath()) (
        "AONLauncherTests_" + [guid]::NewGuid().ToString("N")
    )
    $Global:ConfigFolder = Join-Path $root "Config"
    $Global:BackupFolder = Join-Path $root "Backups"
    $Global:LogFolder = Join-Path $root "Logs"
    $Global:LogFile = Join-Path $Global:LogFolder "launcher.log"

    foreach($folder in @($Global:ConfigFolder, $Global:BackupFolder, $Global:LogFolder)){
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    $defaults = @{
        "settings.json" = [PSCustomObject]@{
            selectedUser = "test-user"
            lastEnvironment = "DEV"
            updateSource = ""
        }
        "users.json" = [PSCustomObject]@{
            defaultUser = "test-user"
            users = @("test-user", "another-user")
        }
        "favorites.json" = [PSCustomObject]@{
            favorites = @()
        }
        "applications.json" = [PSCustomObject]@{
            SSMS = ""
            VisualStudio = ""
            VSCode = ""
            ReportBuilder = ""
            LastScan = ""
        }
        "projects.json" = [PSCustomObject]@{
            projects = @()
        }
        "links.json" = [PSCustomObject]@{
            links = @()
        }
        "credentials.json" = [PSCustomObject]@{
            credentials = @()
        }
    }

    foreach($fileName in $defaults.Keys){
        Save-JsonFile -FileName $fileName -Data $defaults[$fileName]
    }

    New-Item -ItemType File -Path $Global:LogFile -Force | Out-Null
    return $root
}

function Remove-AONTestRoot {

    param(
        [string]$Path
    )

    if($Path -and (Test-Path -LiteralPath $Path)){
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Get-JsonFile {

    param(
        [string]$FileName
    )

    $path = Join-Path $Global:ConfigFolder $FileName
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){
        throw "Test configuration not found: $FileName"
    }

    return [IO.File]::ReadAllText($path) | ConvertFrom-Json
}

function Save-JsonFile {

    param(
        [string]$FileName,
        [object]$Data
    )

    $path = Join-Path $Global:ConfigFolder $FileName
    $json = ConvertTo-Json -InputObject $Data -Depth 20
    [IO.File]::WriteAllText(
        $path,
        $json,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Backup-Configuration {

    $backupPath = Join-Path $Global:BackupFolder (Get-Date -Format "yyyyMMdd_HHmmss_fff")
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    Copy-Item -Path (Join-Path $Global:ConfigFolder "*") -Destination $backupPath -Recurse -Force
    return $backupPath
}

function New-AONTestFile {

    param(
        [string]$Path,
        [string]$Content = "test"
    )

    $parent = Split-Path -Parent $Path
    if($parent){
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($Path, $Content)
    return $Path
}

function Test-AONThrows {

    param(
        [scriptblock]$Action
    )

    try{
        & $Action
        return $false
    }
    catch{
        return $true
    }
}

function Invoke-AONWinFormsDialog {

    param(
        [string]$Title,
        [scriptblock]$ShowForm,
        [scriptblock]$OnShown
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $Global:AONUITestTitle = $Title
    $Global:AONUITestObserve = $OnShown.GetNewClosure()
    $Global:AONUITestForm = $null
    $Global:AONUITestFailure = $null
    $Global:AONUITestTimer = New-Object System.Windows.Forms.Timer
    $Global:AONUITestTimer.Interval = 50
    $Global:AONUITestTimer.Add_Tick({
        foreach($form in [System.Windows.Forms.Application]::OpenForms){
            if($form.Text -ne $Global:AONUITestTitle){
                continue
            }

            $Global:AONUITestForm = $form
            $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
            try{
                & $Global:AONUITestObserve $form
            }
            catch{
                $Global:AONUITestFailure = $_.Exception.Message
            }
            finally{
                $form.Close()
                $Global:AONUITestTimer.Stop()
            }
            break
        }
    })

    $Global:AONUITestTimer.Start()
    try{
        & $ShowForm
    }
    finally{
        $Global:AONUITestTimer.Stop()
        $Global:AONUITestTimer.Dispose()
    }

    $testFailure = $Global:AONUITestFailure
    $testForm = $Global:AONUITestForm
    foreach($variableName in @(
        "AONUITestTitle",
        "AONUITestObserve",
        "AONUITestForm",
        "AONUITestFailure",
        "AONUITestTimer"
    )){
        Remove-Variable -Name $variableName -Scope Global -Force -ErrorAction SilentlyContinue
    }

    if($testFailure){
        throw $testFailure
    }
    if($null -eq $testForm){
        throw "No se abrió el formulario esperado: $Title"
    }

    return $testForm
}
