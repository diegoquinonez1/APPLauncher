$script:APPLauncherTestRepositoryRoot = Split-Path -Parent $PSScriptRoot

if(-not ("APPLauncherTestControlWalker" -as [type])){
    Add-Type -TypeDefinition @"
using System.Collections;
using System.Collections.Generic;
using System.Reflection;

public static class APPLauncherTestControlWalker
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

function New-APPLauncherTestRoot {

    $root = Join-Path ([IO.Path]::GetTempPath()) (
        "APPLauncherTests_" + [guid]::NewGuid().ToString("N")
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

function Remove-APPLauncherTestRoot {

    param(
        [string]$Path
    )

    if($Path -and (Test-Path -LiteralPath $Path)){
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Ensure-TestSettingsShape {

    param(
        [Parameter(Mandatory = $true)]
        [object]$Settings
    )

    if($null -eq $Settings){
        $Settings = [pscustomobject]@{}
    }

    foreach($property in @(
        @{ Name = "selectedUser"; Value = "adm-A0836618" },
        @{ Name = "lastEnvironment"; Value = "DEV" },
        @{ Name = "updateSource"; Value = "" }
    )){
        if($null -eq $Settings.PSObject.Properties[$property.Name]){
            $Settings | Add-Member -Force -NotePropertyName $property.Name -NotePropertyValue $property.Value
        }
    }

    if($null -eq $Settings.PSObject.Properties["cyberArk"]){
        $Settings | Add-Member -Force -NotePropertyName "cyberArk" -NotePropertyValue ([pscustomobject]@{
            enabled = $false
            baseUrl = $null
            loginUrl = "https://aon.cyberark.cloud/privilegecloud/Accounts"
            username = $null
            password = $null
            appId = $null
            interactiveLogin = $true
            allowManualFallback = $true
        })
    }

    return $Settings
}

function Get-JsonFile {

    param(
        [string]$FileName
    )

    $path = Join-Path $Global:ConfigFolder $FileName
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){
        throw "Test configuration not found: $FileName"
    }

    $data = [IO.File]::ReadAllText($path) | ConvertFrom-Json

    if($FileName -eq "settings.json"){
        $normalized = Ensure-TestSettingsShape -Settings $data
        $normalized | ConvertTo-Json -Depth 20 | Set-Content -Path $path -Encoding UTF8
        return $normalized
    }

    return $data
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

function New-APPLauncherTestFile {

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

function Test-APPLauncherThrows {

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

function Invoke-AppLauncherWinFormsDialog {

    param(
        [string]$Title,
        [scriptblock]$ShowForm,
        [scriptblock]$OnShown
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $Global:APPLauncherUITestTitle = $Title
    $Global:APPLauncherUITestObserve = $OnShown.GetNewClosure()
    $Global:APPLauncherUITestForm = $null
    $Global:APPLauncherUITestFailure = $null
    $Global:APPLauncherUITestTimer = New-Object System.Windows.Forms.Timer
    $Global:APPLauncherUITestTimer.Interval = 50
    $Global:APPLauncherUITestTimer.Add_Tick({
        foreach($form in [System.Windows.Forms.Application]::OpenForms){
            if($form.Text -ne $Global:APPLauncherUITestTitle){
                continue
            }

            $Global:APPLauncherUITestForm = $form
            $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
            try{
                & $Global:APPLauncherUITestObserve $form
            }
            catch{
                $Global:APPLauncherUITestFailure = $_.Exception.Message
            }
            finally{
                $form.Close()
                $Global:APPLauncherUITestTimer.Stop()
            }
            break
        }
    })

    $Global:APPLauncherUITestTimer.Start()
    try{
        & $ShowForm
    }
    finally{
        $Global:APPLauncherUITestTimer.Stop()
        $Global:APPLauncherUITestTimer.Dispose()
    }

    $testFailure = $Global:APPLauncherUITestFailure
    $testForm = $Global:APPLauncherUITestForm
    foreach($variableName in @(
        "APPLauncherUITestTitle",
        "APPLauncherUITestObserve",
        "APPLauncherUITestForm",
        "APPLauncherUITestFailure",
        "APPLauncherUITestTimer"
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
