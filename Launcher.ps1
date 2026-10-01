Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# ==================================
# ROOT
# ==================================
$Root = ""

if ($PSScriptRoot) {

    $Root = $PSScriptRoot

}
elseif ($MyInvocation.MyCommand.Path) {

    $Root = Split-Path $MyInvocation.MyCommand.Path -Parent

}
else {

    $Root = Split-Path `
        ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) `
        -Parent

}

# ==================================
# IMPORT MODULES
# ==================================

. "$Root\Modules\ConfigManager.ps1"
. "$Root\Modules\UserManager.ps1"
. "$Root\Modules\LogManager.ps1"
. "$Root\Modules\ApplicationManager.ps1"
. "$Root\Modules\CredentialManager.ps1"
. "$Root\Modules\FavoriteManager.ps1"
. "$Root\Modules\AppLauncher.ps1"
. "$Root\Modules\ThemeManager.ps1"
. "$Root\Modules\UiHelpers.ps1"
. "$Root\Modules\ProfileManager.ps1"
. "$Root\Modules\ProjectLauncher.ps1"
. "$Root\Modules\UsersForm.ps1"
. "$Root\Modules\CredentialForm.ps1"
. "$Root\Modules\FavoriteForm.ps1"

# ==================================
# LOAD DATA
# ==================================

$settings = Get-JsonFile "settings.json"

Scan-Applications | Out-Null

$apps = Get-Applications
$users = Get-Users

# ==================================
# FORM
# ==================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "AON Launcher V4.1"
$form.MinimumSize =
New-Object Drawing.Size(950,800)
$form.Width = 950
$form.Height = 800
$form.StartPosition = "CenterScreen"
$form.MaximizeBox = $false

# ==================================
# USER
# ==================================

$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Text = "Usuario"
$lblUser.Location = New-Object Drawing.Point(20,20)
$lblUser.AutoSize = $true
$form.Controls.Add($lblUser)

$cmbUser = New-Object System.Windows.Forms.ComboBox
$cmbUser.Location = New-Object Drawing.Point(20,45)
$cmbUser.Width = 280

$users.users |
Where-Object {
    $null -ne $_ -and
    -not [string]::IsNullOrWhiteSpace($_)
} |
ForEach-Object {

    [void]$cmbUser.Items.Add($_)

}

if(
    $users.users -contains $settings.selectedUser
){
    $cmbUser.SelectedItem =
        $settings.selectedUser
}
else{
    $cmbUser.SelectedIndex = 0
}

$form.Controls.Add($cmbUser)

$cmbUser.Add_SelectedIndexChanged({

    RefreshDashboard

})

# ==================================
# USERS BUTTON
# ==================================

$btnUsers = New-Object System.Windows.Forms.Button
$btnUsers.Text = "Usuarios"
$btnUsers.Location = New-Object Drawing.Point(320,43)
$btnUsers.Size = New-Object Drawing.Size(120,30)

$btnUsers.Add_Click({

    Show-UsersForm $cmbUser

})

$form.Controls.Add($btnUsers)

# ==================================
# ENVIRONMENT
# ==================================

$grpEnv = New-Object System.Windows.Forms.GroupBox
$grpEnv.Text = "Entorno"
$grpEnv.Location = New-Object Drawing.Point(20,100)
$grpEnv.Size = New-Object Drawing.Size(280,140)

$form.Controls.Add($grpEnv)

$rbDev = New-Object System.Windows.Forms.RadioButton
$rbDev.Text = "DEV"
$rbDev.Location = New-Object Drawing.Point(20,25)

$rbQc = New-Object System.Windows.Forms.RadioButton
$rbQc.Text = "QC"
$rbQc.Location = New-Object Drawing.Point(20,60)

$rbProd = New-Object System.Windows.Forms.RadioButton
$rbProd.Text = "PROD"
$rbProd.Location = New-Object Drawing.Point(20,95)

$grpEnv.Controls.Add($rbDev)
$grpEnv.Controls.Add($rbQc)
$grpEnv.Controls.Add($rbProd)

switch($settings.lastEnvironment){

    "DEV" { $rbDev.Checked = $true }

    "QC" { $rbQc.Checked = $true }

    "PROD" { $rbProd.Checked = $true }

    default { $rbDev.Checked = $true }
}

function Get-SelectedEnvironment {

    if($rbDev.Checked){
        return "DEV"
    }

    if($rbQc.Checked){
        return "QC"
    }

    return "PROD"
}

# ==================================
# ENV LABEL
# ==================================

$lblEnvironment = New-Object System.Windows.Forms.Label
$lblEnvironment.Location = New-Object Drawing.Point(20,250)
$lblEnvironment.AutoSize = $true

$form.Controls.Add($lblEnvironment)

function RefreshEnvironmentLabel {

    $lblEnvironment.Text =
        "Entorno actual: " +
        (Get-SelectedEnvironment)
}

function RefreshDashboard {

    if(
        $null -eq $lblDashUser -or
        $null -eq $lblDashEnv -or
        $null -eq $lblDashApps -or
        $null -eq $lblDashProjects -or
        $null -eq $lblDashFav -or
        $null -eq $lblDashScan
    ){
        return
    }
    
    $apps = Get-Applications

    $projects =
        (Get-Projects).projects

    $favorites =
        (Get-Favorites).favorites

    $appCount = 0

    foreach($item in @(
        $apps.SSMS,
        $apps.VisualStudio,
        $apps.VSCode,
        $apps.ReportBuilder
    ))
    {

        if(
            (
                -not [string]::IsNullOrWhiteSpace($item)
            ) -and (
                Test-Path $item
            )
        ){
            $appCount++
        }

    }

    $lblDashUser.Text =
        "Usuario: " +
        $cmbUser.Text

    $lblDashEnv.Text =
        "Entorno: " +
        (Get-SelectedEnvironment)

    $lblDashApps.Text =
        "Aplicaciones: $appCount / 4"

    $lblDashProjects.Text =
        "Proyectos: " +
        $projects.Count

    $lblDashFav.Text =
        "Favoritos: " +
        $favorites.Count

    $lblDashScan.Text =
        "Último escaneo: " +
        $apps.LastScan

}

function RefreshTheme {

    Set-EnvironmentTheme `
        $form `
        (Get-SelectedEnvironment)
}

$rbDev.Add_CheckedChanged({
    RefreshTheme
    RefreshEnvironmentLabel
    RefreshDashboard
})

$rbQc.Add_CheckedChanged({
    RefreshTheme
    RefreshEnvironmentLabel
    RefreshDashboard
})

$rbProd.Add_CheckedChanged({
    RefreshTheme
    RefreshEnvironmentLabel
    RefreshDashboard
})

RefreshTheme
RefreshEnvironmentLabel

# ==================================
# DASHBOARD
# ==================================

$grpDashboard =
    New-Object System.Windows.Forms.GroupBox

$grpDashboard.Text = "Dashboard"
$grpDashboard.Location =
    New-Object Drawing.Point(20,280)

$grpDashboard.Size =
    New-Object Drawing.Size(280,220)

$form.Controls.Add($grpDashboard)

$lblDashUser =
    New-Object System.Windows.Forms.Label

$lblDashUser.Location =
    New-Object Drawing.Point(20,30)

$lblDashUser.AutoSize = $true

$grpDashboard.Controls.Add(
    $lblDashUser
)

$lblDashEnv =
    New-Object System.Windows.Forms.Label

$lblDashEnv.Location =
    New-Object Drawing.Point(20,60)

$lblDashEnv.AutoSize = $true

$grpDashboard.Controls.Add(
    $lblDashEnv
)

$lblDashApps =
    New-Object System.Windows.Forms.Label

$lblDashApps.Location =
    New-Object Drawing.Point(20,90)

$lblDashApps.AutoSize = $true

$grpDashboard.Controls.Add(
    $lblDashApps
)

$lblDashProjects =
    New-Object System.Windows.Forms.Label

$lblDashProjects.Location =
    New-Object Drawing.Point(20,120)

$lblDashProjects.AutoSize = $true

$grpDashboard.Controls.Add(
    $lblDashProjects
)

$lblDashFav =
    New-Object System.Windows.Forms.Label

$lblDashFav.Location =
    New-Object Drawing.Point(20,150)

$lblDashFav.AutoSize = $true

$grpDashboard.Controls.Add(
    $lblDashFav
)

$lblDashScan =
    New-Object System.Windows.Forms.Label

$lblDashScan.Location =
    New-Object Drawing.Point(20,180)

$lblDashScan.AutoSize = $true

$grpDashboard.Controls.Add(
    $lblDashScan
)

RefreshDashboard

# ==================================
# APPLICATIONS
# ==================================

$btnSSMS = New-Object System.Windows.Forms.Button
$btnSSMS.Text = "SSMS"
$btnSSMS.Location = New-Object Drawing.Point(350,80)
$btnSSMS.Size = New-Object Drawing.Size(200,60)

$btnSSMS.Add_Click({

    Invoke-Safely {

        Start-AONApplication `
            "SSMS" `
            (Get-SelectedEnvironment) `
            $cmbUser.Text

    }

})

$form.Controls.Add($btnSSMS)

# ------------------------------

$btnVS = New-Object System.Windows.Forms.Button
$btnVS.Text = "Visual Studio"
$btnVS.Location = New-Object Drawing.Point(580,80)
$btnVS.Size = New-Object Drawing.Size(200,60)

$btnVS.Add_Click({

    Invoke-Safely {

        Start-AONApplication `
            "VisualStudio" `
            (Get-SelectedEnvironment) `
            $cmbUser.Text

    }

})

$form.Controls.Add($btnVS)

# ------------------------------

$btnCode = New-Object System.Windows.Forms.Button
$btnCode.Text = "VS Code"
$btnCode.Location = New-Object Drawing.Point(350,170)
$btnCode.Size = New-Object Drawing.Size(200,60)

$btnCode.Add_Click({

    Invoke-Safely {

        Start-AONApplication `
            "VSCode" `
            (Get-SelectedEnvironment) `
            $cmbUser.Text

    }

})

$form.Controls.Add($btnCode)

# ------------------------------

$btnReport = New-Object System.Windows.Forms.Button
$btnReport.Text = "Report Builder"
$btnReport.Location = New-Object Drawing.Point(580,170)
$btnReport.Size = New-Object Drawing.Size(200,60)

$btnReport.Add_Click({

    Invoke-Safely {

        Start-AONApplication `
            "ReportBuilder" `
            (Get-SelectedEnvironment) `
            $cmbUser.Text

    }

})

$form.Controls.Add($btnReport)

# ==================================
# TOOLS
# ==================================

$btnCreds = New-Object System.Windows.Forms.Button
$btnCreds.Text = "Credenciales"
$btnCreds.Location = New-Object Drawing.Point(350,280)
$btnCreds.Size = New-Object Drawing.Size(200,40)

$btnCreds.Add_Click({

    Invoke-Safely {

        Show-CredentialForm `
            (Get-Users).users

    }

})

$form.Controls.Add($btnCreds)

$btnFav = New-Object System.Windows.Forms.Button

$btnFav.Text = "Favoritos"
$btnFav.Location = New-Object Drawing.Point(580,335)
$btnFav.Size = New-Object Drawing.Size(200,40)

$btnFav.Add_Click({

    Invoke-Safely {

        Show-FavoriteForm

    }

})

$form.Controls.Add($btnFav)

# ------------------------------

$btnLogs = New-Object System.Windows.Forms.Button
$btnLogs.Text = "Logs"
$btnLogs.Location = New-Object Drawing.Point(580,280)
$btnLogs.Size = New-Object Drawing.Size(200,40)

$btnLogs.Add_Click({

    Invoke-Safely {

        notepad.exe `
            "$Root\Logs\launcher.log"

    }

})

$form.Controls.Add($btnLogs)

# ==================================
# RE-SCAN
# ==================================

function Get-AppStatus {

    param($Path)

    if(
        -not [string]::IsNullOrWhiteSpace($Path) `
        -and
        (Test-Path $Path)
    ){
        return "[OK]"
    }

    return "[NO]"
}

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "Reescanear"
$btnScan.Location = New-Object Drawing.Point(350,535)
$btnScan.Size = New-Object Drawing.Size(430,40)

$form.Controls.Add($btnScan)

# ==================================
# STATUS
# ==================================

$grpStatus = New-Object System.Windows.Forms.GroupBox
$grpStatus.Text = "Estado de Aplicaciones"
$grpStatus.Location = New-Object Drawing.Point(20,520)
$grpStatus.Size = New-Object Drawing.Size(280,220)

$form.Controls.Add($grpStatus)

$lblSSMSStatus = New-Object System.Windows.Forms.Label
$lblSSMSStatus.Location = New-Object Drawing.Point(20,30)
$lblSSMSStatus.AutoSize = $true

$lblVSStatus = New-Object System.Windows.Forms.Label
$lblVSStatus.Location = New-Object Drawing.Point(20,60)
$lblVSStatus.AutoSize = $true

$lblCodeStatus = New-Object System.Windows.Forms.Label
$lblCodeStatus.Location = New-Object Drawing.Point(20,90)
$lblCodeStatus.AutoSize = $true

$lblReportStatus = New-Object System.Windows.Forms.Label
$lblReportStatus.Location = New-Object Drawing.Point(20,120)
$lblReportStatus.AutoSize = $true

$lblSummary = New-Object System.Windows.Forms.Label
$lblSummary.Location = New-Object Drawing.Point(20,150)
$lblSummary.AutoSize = $true
$lblSummary.Font = New-Object System.Drawing.Font(
    "Segoe UI",
    9,
    [System.Drawing.FontStyle]::Bold
)

$grpStatus.Controls.Add($lblSSMSStatus)
$grpStatus.Controls.Add($lblVSStatus)
$grpStatus.Controls.Add($lblCodeStatus)
$grpStatus.Controls.Add($lblReportStatus)
$grpStatus.Controls.Add($lblSummary)

function Set-StatusLabel {

    param(
        [System.Windows.Forms.Label]$Label,
        [string]$ApplicationName,
        [string]$Path
    )

    if(
        -not [string]::IsNullOrWhiteSpace($Path) `
        -and
        (Test-Path $Path)
    ){

        $Label.Text =
            "[OK] " + $ApplicationName + " - Disponible"

        $Label.ForeColor =
            [System.Drawing.Color]::DarkGreen

        return $true

    }

    $Label.Text =
        "[ERROR] " + $ApplicationName + " - No encontrado"

    $Label.ForeColor =
        [System.Drawing.Color]::DarkRed

    return $false

}

function RefreshAppStatus {

    $script:apps = Get-Applications

    $available = 0

    if(
        Set-StatusLabel `
            $lblSSMSStatus `
            "SSMS" `
            $apps.SSMS
    ){
        $available++
    }

    if(
        Set-StatusLabel `
            $lblVSStatus `
            "Visual Studio" `
            $apps.VisualStudio
    ){
        $available++
    }

    if(
        Set-StatusLabel `
            $lblCodeStatus `
            "VS Code" `
            $apps.VSCode
    ){
        $available++
    }

    if(
        Set-StatusLabel `
            $lblReportStatus `
            "Report Builder" `
            $apps.ReportBuilder
    ){
        $available++
    }

    $lblSummary.Text =
        "Disponibles: $available / 4"

    if($available -eq 4){

        $lblSummary.ForeColor =
            [System.Drawing.Color]::DarkGreen

    }
    else{

        $lblSummary.ForeColor =
            [System.Drawing.Color]::DarkOrange

    }

}

RefreshAppStatus

$btnScan.Add_Click({

    Invoke-Safely {

        Scan-Applications | Out-Null

        RefreshAppStatus
        RefreshDashboard

        Show-Info "Escaneo completado."

    }

})

# ==================================
# PROJECTS
# ==================================

$grpProjects = New-Object System.Windows.Forms.GroupBox
$grpProjects.Text = "Proyectos"
$grpProjects.Location = New-Object Drawing.Point(350,390)
$grpProjects.Size = New-Object Drawing.Size(430,310)

$flowProjectButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$flowProjectButtons.Location = New-Object Drawing.Point(10,25)
$flowProjectButtons.Size = New-Object Drawing.Size(400,270)
$flowProjectButtons.AutoScroll = $true
$flowProjectButtons.FlowDirection = "TopDown"
$flowProjectButtons.WrapContents = $false

$grpProjects.Controls.Add($flowProjectButtons)
$form.Controls.Add($grpProjects)

function Refresh-ProjectLauncher {

    $flowProjectButtons.Controls.Clear()
    $projectDefinitions = @((Get-Projects).projects)

    foreach($project in $projectDefinitions){

        if(
            $null -eq $project -or
            [string]::IsNullOrWhiteSpace([string]$project.name)
        ){
            continue
        }

        $projectButton = New-Object System.Windows.Forms.Button
        $projectButton.Text = [string]$project.name
        $projectButton.Tag = $project
        $projectButton.Size = New-Object Drawing.Size(370,42)

        $projectButton.Add_Click({
            param($sender, $eventArgs)

            Invoke-Safely {
                Start-ProjectProfile -Project $sender.Tag
            }
        })

        $flowProjectButtons.Controls.Add($projectButton)

    }

    if($flowProjectButtons.Controls.Count -eq 0){

        $emptyProjectsLabel = New-Object System.Windows.Forms.Label
        $emptyProjectsLabel.Text = "No hay proyectos configurados."
        $emptyProjectsLabel.AutoSize = $true
        $flowProjectButtons.Controls.Add($emptyProjectsLabel)

    }

}

Refresh-ProjectLauncher

# ==================================
# EXIT
# ==================================

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Salir"
$btnExit.Location = New-Object Drawing.Point(780,720)
$btnExit.Size = New-Object Drawing.Size(120,35)

$btnExit.Add_Click({

    $form.Close()

})

$form.Controls.Add($btnExit)

# ==================================
# SAVE SETTINGS
# ==================================

$form.Add_FormClosing({

    Invoke-Safely {

        $settings =
            Get-JsonFile "settings.json"

        $settings.selectedUser =
            $cmbUser.Text

        $settings.lastEnvironment =
            Get-SelectedEnvironment

        Save-JsonFile `
            "settings.json" `
            $settings

    }

})

# ==================================
# SHOW
# ==================================

[void]$form.ShowDialog()