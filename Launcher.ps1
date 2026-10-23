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
. "$Root\Modules\ProfileTransfer.ps1"
. "$Root\Modules\UserManager.ps1"
. "$Root\Modules\LogManager.ps1"
. "$Root\Modules\ApplicationManager.ps1"
. "$Root\Modules\CredentialManager.ps1"
. "$Root\Modules\FavoriteManager.ps1"
. "$Root\Modules\QuickLinks.ps1"
. "$Root\Modules\AppLauncher.ps1"
. "$Root\Modules\ThemeManager.ps1"
. "$Root\Modules\UiHelpers.ps1"
. "$Root\Modules\ProfileManager.ps1"
. "$Root\Modules\ProjectLauncher.ps1"
. "$Root\Modules\ProjectsForm.ps1"
. "$Root\Modules\UsersForm.ps1"
. "$Root\Modules\CredentialForm.ps1"
. "$Root\Modules\FavoriteForm.ps1"
. "$Root\Modules\QuickLinksForm.ps1"

# ==================================
# LOAD DATA
# ==================================

$settings = Get-JsonFile "settings.json"
Remove-ExpiredLauncherCredentials | Out-Null

Scan-Applications | Out-Null

$apps = Get-Applications
$users = Get-Users

# ==================================
# FORM
# ==================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "AON Launcher V4.4"
$screenArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.AutoScroll = $true
$form.AutoScrollMinSize = New-Object Drawing.Size(920,960)
$form.MinimumSize = New-Object Drawing.Size(
    [Math]::Min(950, $screenArea.Width),
    [Math]::Min(600, $screenArea.Height)
)
$form.Size = New-Object Drawing.Size(
    [Math]::Min(950, $screenArea.Width),
    [Math]::Min(800, $screenArea.Height)
)
$form.StartPosition = "CenterScreen"
$form.MaximizeBox = $true

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
        $null -eq $lblDashScan -or
        $null -eq $lblDashLastApp -or
        $null -eq $lblDashLastProject -or
        $null -eq $lblDashTopApp -or
        $null -eq $lblDashTopProject -or
        $null -eq $lblDashToday -or
        $null -eq $lblDashMonth -or
        $null -eq $lblDashCredentialDev -or
        $null -eq $lblDashCredentialQc -or
        $null -eq $lblDashCredentialProd
    ){
        return
    }
    
    $apps = Get-Applications

    $projects =
        (Get-Projects).projects

    $favorites =
        (Get-Favorites).favorites

    $metrics = Get-LauncherDashboardMetrics

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

    $lblDashLastApp.Text = "Última aplicación: Sin registros"
    if($null -ne $metrics.LatestApplication){
        $lblDashLastApp.Text = "Última aplicación: {0} ({1})" -f `
            $metrics.LatestApplication.Name,
            $metrics.LatestApplication.Timestamp.ToString("dd/MM HH:mm")
    }

    $lblDashLastProject.Text = "Último proyecto: Sin registros"
    if($null -ne $metrics.LatestProject){
        $lblDashLastProject.Text = "Último proyecto: {0} ({1})" -f `
            $metrics.LatestProject.Name,
            $metrics.LatestProject.Timestamp.ToString("dd/MM HH:mm")
    }

    $lblDashTopApp.Text = "Aplicación más usada: Sin registros"
    if($null -ne $metrics.MostUsedApplication){
        $lblDashTopApp.Text = "Aplicación más usada: {0} ({1})" -f `
            $metrics.MostUsedApplication.Name,
            $metrics.MostUsedApplication.Count
    }

    $lblDashTopProject.Text = "Proyecto más usado: Sin registros"
    if($null -ne $metrics.MostUsedProject){
        $lblDashTopProject.Text = "Proyecto más usado: {0} ({1})" -f `
            $metrics.MostUsedProject.Name,
            $metrics.MostUsedProject.Count
    }

    $lblDashToday.Text = "Ejecuciones de apps hoy: $($metrics.ExecutionsToday)"
    $lblDashMonth.Text = "Ejecuciones de apps este mes: $($metrics.ExecutionsThisMonth)"

    $lblDashCredentialDev.Text = "Credencial DEV: " + (Get-LauncherCredentialStatus "DEV" $cmbUser.Text).Status
    $lblDashCredentialQc.Text = "Credencial QC: " + (Get-LauncherCredentialStatus "QC" $cmbUser.Text).Status
    $lblDashCredentialProd.Text = "Credencial PROD: " + (Get-LauncherCredentialStatus "PROD" $cmbUser.Text).Status

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
    New-Object Drawing.Size(280,450)

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

$lblDashLastApp = New-Object System.Windows.Forms.Label
$lblDashLastProject = New-Object System.Windows.Forms.Label
$lblDashTopApp = New-Object System.Windows.Forms.Label
$lblDashTopProject = New-Object System.Windows.Forms.Label
$lblDashToday = New-Object System.Windows.Forms.Label
$lblDashMonth = New-Object System.Windows.Forms.Label
$dashboardMetricLabels = @(
    $lblDashLastApp,
    $lblDashLastProject,
    $lblDashTopApp,
    $lblDashTopProject,
    $lblDashToday,
    $lblDashMonth
)

for($index = 0; $index -lt $dashboardMetricLabels.Count; $index++){
    $dashboardMetricLabels[$index].Location = New-Object Drawing.Point(
        20,
        (210 + ($index * 24))
    )
    $dashboardMetricLabels[$index].Size = New-Object Drawing.Size(240,22)
    $dashboardMetricLabels[$index].AutoEllipsis = $true
    $grpDashboard.Controls.Add($dashboardMetricLabels[$index])
}

$lblDashCredentialDev = New-Object System.Windows.Forms.Label
$lblDashCredentialQc = New-Object System.Windows.Forms.Label
$lblDashCredentialProd = New-Object System.Windows.Forms.Label
$credentialStatusLabels = @(
    $lblDashCredentialDev,
    $lblDashCredentialQc,
    $lblDashCredentialProd
)

for($index = 0; $index -lt $credentialStatusLabels.Count; $index++){
    $credentialStatusLabels[$index].Location = New-Object Drawing.Point(
        20,
        (360 + ($index * 24))
    )
    $credentialStatusLabels[$index].Size = New-Object Drawing.Size(240,22)
    $credentialStatusLabels[$index].AutoEllipsis = $true
    $grpDashboard.Controls.Add($credentialStatusLabels[$index])
}

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

        RefreshDashboard

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

        RefreshDashboard

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

        RefreshDashboard

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

        RefreshDashboard

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
            (Get-Users).users `
            $form

        RefreshDashboard

    }

})

$form.Controls.Add($btnCreds)

$btnProjectsManager = New-Object System.Windows.Forms.Button
$btnProjectsManager.Text = "Proyectos"
$btnProjectsManager.Location = New-Object Drawing.Point(350,335)
$btnProjectsManager.Size = New-Object Drawing.Size(200,40)

$btnProjectsManager.Add_Click({

    Invoke-Safely {

        Show-ProjectsForm
        Refresh-ProjectLauncher

    }

})

$form.Controls.Add($btnProjectsManager)

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

$btnExportProfile = New-Object System.Windows.Forms.Button
$btnExportProfile.Text = "Exportar perfil"
$btnExportProfile.Location = New-Object Drawing.Point(790,280)
$btnExportProfile.Size = New-Object Drawing.Size(140,40)
$btnExportProfile.Add_Click({

    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = "Perfil AON (*.profile.zip)|*.profile.zip"
    $dialog.DefaultExt = "profile.zip"
    $dialog.AddExtension = $true
    $dialog.FileName = "$env:USERNAME.profile.zip"

    if($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK){
        return
    }

    $passphrase = Show-LauncherProfilePassphraseDialog `
        -Title "Proteger perfil exportado" `
        -ConfirmPassphrase $true `
        -Owner $form

    if($null -eq $passphrase){
        return
    }

    try{
        Export-LauncherProfile `
            -DestinationPath $dialog.FileName `
            -Passphrase $passphrase

        Show-Info "Perfil exportado correctamente. Guarde la frase de paso: se necesitará para importarlo."
    }
    catch{
        Show-Error $_.Exception.Message
    }
    finally{
        $passphrase.Dispose()
        $dialog.Dispose()
    }

})
$form.Controls.Add($btnExportProfile)

$btnImportProfile = New-Object System.Windows.Forms.Button
$btnImportProfile.Text = "Importar perfil"
$btnImportProfile.Location = New-Object Drawing.Point(790,335)
$btnImportProfile.Size = New-Object Drawing.Size(140,40)
$btnImportProfile.Add_Click({

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Perfil AON (*.profile.zip)|*.profile.zip|ZIP (*.zip)|*.zip"
    $dialog.CheckFileExists = $true

    if($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK){
        $dialog.Dispose()
        return
    }

    $confirmation = [System.Windows.Forms.MessageBox]::Show(
        "La importación reemplazará usuarios, favoritos, credenciales, proyectos, enlaces y configuración. Se creará un respaldo automático. ¿Desea continuar?",
        "Confirmar importación de perfil",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if($confirmation -ne [System.Windows.Forms.DialogResult]::Yes){
        $dialog.Dispose()
        return
    }

    $passphrase = Show-LauncherProfilePassphraseDialog `
        -Title "Desproteger perfil" `
        -ConfirmPassphrase $false `
        -Owner $form

    if($null -eq $passphrase){
        $dialog.Dispose()
        return
    }

    try{
        $result = Import-LauncherProfile `
            -SourcePath $dialog.FileName `
            -Passphrase $passphrase

        Update-LauncherAfterProfileImport
        Show-Info "Perfil importado. Se actualizaron $($result.ImportedFiles) archivos y se creó un respaldo de la configuración anterior."
    }
    catch{
        Show-Error $_.Exception.Message
    }
    finally{
        $passphrase.Dispose()
        $dialog.Dispose()
    }

})
$form.Controls.Add($btnImportProfile)

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
$btnScan.Location = New-Object Drawing.Point(20,180)
$btnScan.Size = New-Object Drawing.Size(240,32)

# ==================================
# STATUS
# ==================================

$grpStatus = New-Object System.Windows.Forms.GroupBox
$grpStatus.Text = "Estado de Aplicaciones"
$grpStatus.Location = New-Object Drawing.Point(20,660)
$grpStatus.Size = New-Object Drawing.Size(280,260)

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
$grpStatus.Controls.Add($btnScan)

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
$grpProjects.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top -bor
    [System.Windows.Forms.AnchorStyles]::Bottom -bor
    [System.Windows.Forms.AnchorStyles]::Left -bor
    [System.Windows.Forms.AnchorStyles]::Right
)

$flowProjectButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$flowProjectButtons.Location = New-Object Drawing.Point(10,25)
$flowProjectButtons.Size = New-Object Drawing.Size(400,270)
$flowProjectButtons.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top -bor
    [System.Windows.Forms.AnchorStyles]::Bottom -bor
    [System.Windows.Forms.AnchorStyles]::Left -bor
    [System.Windows.Forms.AnchorStyles]::Right
)
$flowProjectButtons.AutoScroll = $true
$flowProjectButtons.FlowDirection = "TopDown"
$flowProjectButtons.WrapContents = $false

$flowProjectButtons.Add_SizeChanged({

    $buttonWidth = [Math]::Max(
        120,
        $flowProjectButtons.ClientSize.Width - 28
    )

    foreach($button in $flowProjectButtons.Controls){
        if($button -is [System.Windows.Forms.Button]){
            $button.Width = $buttonWidth
        }
    }

})

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
        $projectButton.Size = New-Object Drawing.Size(
            [Math]::Max(120, $flowProjectButtons.ClientSize.Width - 28),
            42
        )

        $projectButton.Add_Click({
            param($sender, $eventArgs)

            Invoke-Safely {
                Start-ProjectProfile -Project $sender.Tag
                RefreshDashboard
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
# QUICK LINKS
# ==================================

$grpQuickLinks = New-Object System.Windows.Forms.GroupBox
$grpQuickLinks.Text = "Accesos web"
$grpQuickLinks.Location = New-Object Drawing.Point(350,710)
$grpQuickLinks.Size = New-Object Drawing.Size(430,220)
$grpQuickLinks.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top -bor
    [System.Windows.Forms.AnchorStyles]::Left -bor
    [System.Windows.Forms.AnchorStyles]::Right
)

$flowQuickLinks = New-Object System.Windows.Forms.FlowLayoutPanel
$flowQuickLinks.Location = New-Object Drawing.Point(10,25)
$flowQuickLinks.Size = New-Object Drawing.Size(400,140)
$flowQuickLinks.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top -bor
    [System.Windows.Forms.AnchorStyles]::Left -bor
    [System.Windows.Forms.AnchorStyles]::Right
)
$flowQuickLinks.AutoScroll = $true
$flowQuickLinks.FlowDirection = "TopDown"
$flowQuickLinks.WrapContents = $false
$grpQuickLinks.Controls.Add($flowQuickLinks)

$btnManageQuickLinks = New-Object System.Windows.Forms.Button
$btnManageQuickLinks.Text = "Administrar accesos web"
$btnManageQuickLinks.Location = New-Object Drawing.Point(10,175)
$btnManageQuickLinks.Size = New-Object Drawing.Size(400,30)
$btnManageQuickLinks.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Bottom -bor
    [System.Windows.Forms.AnchorStyles]::Left -bor
    [System.Windows.Forms.AnchorStyles]::Right
)
$btnManageQuickLinks.Add_Click({

    Invoke-Safely {
        Show-QuickLinksForm
        Refresh-QuickLinks
    }

})
$grpQuickLinks.Controls.Add($btnManageQuickLinks)
$form.Controls.Add($grpQuickLinks)

function Refresh-QuickLinks {

    $flowQuickLinks.Controls.Clear()
    $links = @(Get-QuickLinks)
    $invalidLinks = 0

    foreach($link in $links){

        try{
            $validatedLink = ConvertTo-QuickLink $link
        }
        catch{
            $invalidLinks++
            continue
        }

        $linkButton = New-Object System.Windows.Forms.Button
        $linkButton.Text = $validatedLink.name
        $linkButton.Tag = $validatedLink
        $linkButton.Size = New-Object Drawing.Size(
            [Math]::Max(120, $flowQuickLinks.ClientSize.Width - 28),
            36
        )
        $linkButton.Add_Click({
            param($control, $eventRecord)

            Invoke-Safely {
                Open-QuickLink -Link $control.Tag
            }
        })

        $flowQuickLinks.Controls.Add($linkButton)
    }

    if($flowQuickLinks.Controls.Count -eq 0){

        $emptyLinksLabel = New-Object System.Windows.Forms.Label
        if($invalidLinks -gt 0){
            $emptyLinksLabel.Text = "Revise los enlaces inválidos en el gestor."
        }
        else{
            $emptyLinksLabel.Text = "No hay accesos web configurados."
        }
        $emptyLinksLabel.AutoSize = $true
        $flowQuickLinks.Controls.Add($emptyLinksLabel)
    }
}

Refresh-QuickLinks

function Update-LauncherAfterProfileImport {

    $settings = Get-JsonFile "settings.json"
    $users = Get-Users
    $cmbUser.Items.Clear()

    foreach($user in @($users.users)){
        if(-not [string]::IsNullOrWhiteSpace([string]$user)){
            [void]$cmbUser.Items.Add([string]$user)
        }
    }

    if($cmbUser.Items.Contains([string]$settings.selectedUser)){
        $cmbUser.SelectedItem = [string]$settings.selectedUser
    }
    elseif($cmbUser.Items.Count -gt 0){
        $cmbUser.SelectedIndex = 0
    }
    else{
        $cmbUser.SelectedIndex = -1
    }

    switch([string]$settings.lastEnvironment){
        "DEV" { $rbDev.Checked = $true }
        "QC" { $rbQc.Checked = $true }
        "PROD" { $rbProd.Checked = $true }
        default { $rbDev.Checked = $true }
    }

    RefreshAppStatus
    Refresh-ProjectLauncher
    Refresh-QuickLinks
    RefreshDashboard
}

# ==================================
# EXIT
# ==================================

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Salir"
$btnExit.Location = New-Object Drawing.Point(780,720)
$btnExit.Size = New-Object Drawing.Size(120,35)
$btnExit.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Bottom -bor
    [System.Windows.Forms.AnchorStyles]::Right
)

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

$credentialCleanupTimer = New-Object System.Windows.Forms.Timer
$credentialCleanupTimer.Interval = 60000
$credentialCleanupTimer.Add_Tick({

    $removedCredentials = Remove-ExpiredLauncherCredentials

    if($removedCredentials -gt 0){

        RefreshDashboard

    }

})
$form.Add_FormClosed({

    $credentialCleanupTimer.Stop()
    $credentialCleanupTimer.Dispose()

})
$credentialCleanupTimer.Start()

# ==================================
# SHOW
# ==================================

[void]$form.ShowDialog()