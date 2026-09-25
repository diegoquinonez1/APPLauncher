Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# ==================================
# ROOT
# ==================================

$Root = Split-Path $MyInvocation.MyCommand.Path -Parent

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
New-Object Drawing.Size(950,700)
$form.Width = 950
$form.Height = 700
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

$users.users | ForEach-Object {
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

function RefreshTheme {

    Set-EnvironmentTheme `
        $form `
        (Get-SelectedEnvironment)
}

$rbDev.Add_CheckedChanged({
    RefreshTheme
    RefreshEnvironmentLabel
})

$rbQc.Add_CheckedChanged({
    RefreshTheme
    RefreshEnvironmentLabel
})

$rbProd.Add_CheckedChanged({
    RefreshTheme
    RefreshEnvironmentLabel
})

RefreshTheme
RefreshEnvironmentLabel

# ==================================
# APPLICATIONS
# ==================================

$btnSSMS = New-Object System.Windows.Forms.Button
$btnSSMS.Text = "SSMS"
$btnSSMS.Location = New-Object Drawing.Point(350,80)
$btnSSMS.Size = New-Object Drawing.Size(200,60)

$btnSSMS.Add_Click({

    try{

        Start-AONApplication `
            "SSMS" `
            (Get-SelectedEnvironment) `
            $cmbUser.Text

    }
    catch{

        Show-Error $_.Exception.Message

    }
})

$form.Controls.Add($btnSSMS)

# ------------------------------

$btnVS = New-Object System.Windows.Forms.Button
$btnVS.Text = "Visual Studio"
$btnVS.Location = New-Object Drawing.Point(580,80)
$btnVS.Size = New-Object Drawing.Size(200,60)

$btnVS.Add_Click({

    try{

        Start-AONApplication `
            "VisualStudio" `
            (Get-SelectedEnvironment) `
            $cmbUser.Text

    }
    catch{

        Show-Error $_.Exception.Message

    }

})

$form.Controls.Add($btnVS)

# ------------------------------

$btnCode = New-Object System.Windows.Forms.Button
$btnCode.Text = "VS Code"
$btnCode.Location = New-Object Drawing.Point(350,170)
$btnCode.Size = New-Object Drawing.Size(200,60)

$btnCode.Add_Click({

    try{

        Start-AONApplication `
            "VSCode" `
            (Get-SelectedEnvironment) `
            $cmbUser.Text

    }
    catch{

        Show-Error $_.Exception.Message

    }

})

$form.Controls.Add($btnCode)

# ------------------------------

$btnReport = New-Object System.Windows.Forms.Button
$btnReport.Text = "Report Builder"
$btnReport.Location = New-Object Drawing.Point(580,170)
$btnReport.Size = New-Object Drawing.Size(200,60)

$btnReport.Add_Click({

    try{

        Start-AONApplication `
            "ReportBuilder" `
            (Get-SelectedEnvironment) `
            $cmbUser.Text

    }
    catch{

        Show-Error $_.Exception.Message

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

    Show-CredentialForm `
        (Get-Users).users

})

$form.Controls.Add($btnCreds)

$btnFav = New-Object System.Windows.Forms.Button

$btnFav.Text = "Favoritos"
$btnFav.Location = New-Object Drawing.Point(580,335)
$btnFav.Size = New-Object Drawing.Size(200,40)

$btnFav.Add_Click({

    Show-FavoriteForm

})

$form.Controls.Add($btnFav)

# ------------------------------

$btnLogs = New-Object System.Windows.Forms.Button
$btnLogs.Text = "Logs"
$btnLogs.Location = New-Object Drawing.Point(580,280)
$btnLogs.Size = New-Object Drawing.Size(200,40)

$btnLogs.Add_Click({

    notepad.exe `
        "$Root\Logs\launcher.log"

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
$grpStatus.Location = New-Object Drawing.Point(20,300)
$grpStatus.Size = New-Object Drawing.Size(280,180)

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

$grpStatus.Controls.Add($lblSSMSStatus)
$grpStatus.Controls.Add($lblVSStatus)
$grpStatus.Controls.Add($lblCodeStatus)
$grpStatus.Controls.Add($lblReportStatus)

function RefreshAppStatus {

    $script:apps = Get-Applications

    $lblSSMSStatus.Text =
        "SSMS : " +
        (Get-AppStatus $apps.SSMS)

    $lblVSStatus.Text =
        "Visual Studio : " +
        (Get-AppStatus $apps.VisualStudio)

    $lblCodeStatus.Text =
        "VS Code : " +
        (Get-AppStatus $apps.VSCode)

    $lblReportStatus.Text =
        "Report Builder : " +
        (Get-AppStatus $apps.ReportBuilder)
}

RefreshAppStatus

$btnScan.Add_Click({

    Scan-Applications | Out-Null

    RefreshAppStatus

    Show-Info "Escaneo completado."

})

# ==================================
# BAIS
# ==================================

$btnBAIS = New-Object System.Windows.Forms.Button
$btnBAIS.Text = "Iniciar BAIS"
$btnBAIS.Location = New-Object Drawing.Point(350,420)
$btnBAIS.Size = New-Object Drawing.Size(430,70)

$form.Controls.Add($btnBAIS)

$btnBAIS.Add_Click({

    try{

        Start-ProjectProfile `
            "BAIS DEV"

    }
    catch{

        Show-Error `
            $_.Exception.Message

    }

})

# ==================================
# EXIT
# ==================================

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Salir"
$btnExit.Location = New-Object Drawing.Point(780,600)
$btnExit.Size = New-Object Drawing.Size(120,35)

$btnExit.Add_Click({

    $form.Close()

})

$form.Controls.Add($btnExit)

# ==================================
# SAVE SETTINGS
# ==================================

$form.Add_FormClosing({

    $settings =
        Get-JsonFile "settings.json"

    $settings.selectedUser =
        $cmbUser.Text

    $settings.lastEnvironment =
        Get-SelectedEnvironment

    Save-JsonFile `
        "settings.json" `
        $settings

})

# ==================================
# SHOW
# ==================================

[void]$form.ShowDialog()