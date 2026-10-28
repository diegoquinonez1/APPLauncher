Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

try{
    $launcherScriptPath = if($PSScriptRoot){
        $PSScriptRoot
    }
    elseif($MyInvocation.MyCommand.Path){
        Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    }
    else{
        Split-Path -Path ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) -Parent
    }

    $launcherScriptPath = [System.IO.Path]::GetFullPath((Join-Path $launcherScriptPath 'Launcher.ps1'))
    $launcherPattern = [regex]::Escape($launcherScriptPath)

    $staleLauncherPids = Get-CimInstance Win32_Process -ErrorAction Stop |
        Where-Object {
            $_.Name -match '^(pwsh|powershell)\.exe$' -and
            $_.ProcessId -ne $PID -and
            $_.CommandLine -and
            $_.CommandLine -match $launcherPattern
        } |
        Select-Object -ExpandProperty ProcessId -Unique

    foreach($stalePid in $staleLauncherPids){
        Stop-Process -Id $stalePid -Force -ErrorAction SilentlyContinue
    }
}
catch{}

if($null -ne $script:clipboardTimer){
    try{
        $script:clipboardTimer.Stop()
        $script:clipboardTimer.Dispose()
    }
    catch{}
    finally{
        $script:clipboardTimer = $null
    }
}

Remove-Variable -Name CyberArkInteractiveLoginOpened -Scope Script -Force -ErrorAction SilentlyContinue

if(Test-Path Function:\Stop-ClipboardResetTimer){
    Remove-Item Function:\Stop-ClipboardResetTimer -Force -ErrorAction SilentlyContinue
}

if(Test-Path Function:\Show-CredentialForm){
    Remove-Item Function:\Show-CredentialForm -Force -ErrorAction SilentlyContinue
}

Remove-Variable -Name clipboardTimer -Scope Script -Force -ErrorAction SilentlyContinue

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
. "$Root\Modules\UpdateManager.ps1"
. "$Root\Modules\UserManager.ps1"
. "$Root\Modules\LogManager.ps1"
. "$Root\Modules\ApplicationManager.ps1"
. "$Root\Modules\CyberArkProvider.ps1"
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
$form.Text = "APPLauncher V$($script:LauncherVersion.ToString(3))"
$screenArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.AutoScroll = $false
$form.MinimumSize = New-Object Drawing.Size(
    [Math]::Min(820, $screenArea.Width),
    [Math]::Min(680, $screenArea.Height)
)
$form.Size = New-Object Drawing.Size(
    [Math]::Min(1000, $screenArea.Width),
    [Math]::Min(760, $screenArea.Height)
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
$rbDev.AutoSize = $true
$rbDev.Margin = New-Object System.Windows.Forms.Padding(3,7,8,3)

$rbQc = New-Object System.Windows.Forms.RadioButton
$rbQc.Text = "QC"
$rbQc.AutoSize = $true
$rbQc.Margin = New-Object System.Windows.Forms.Padding(3,7,8,3)

$rbProd = New-Object System.Windows.Forms.RadioButton
$rbProd.Text = "PROD"
$rbProd.AutoSize = $true
$rbProd.Margin = New-Object System.Windows.Forms.Padding(3,7,3,3)

$environmentOptions = New-Object System.Windows.Forms.FlowLayoutPanel
$environmentOptions.Location = New-Object Drawing.Point(7,17)
$environmentOptions.Size = New-Object Drawing.Size(265,38)
$environmentOptions.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$environmentOptions.WrapContents = $false
$environmentOptions.AutoScroll = $true
$environmentOptions.Controls.AddRange(@($rbDev, $rbQc, $rbProd))
$grpEnv.Controls.Add($environmentOptions)

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

    foreach($surface in @($script:launcherThemeSurfaces)){
        if($null -ne $surface){
            $surface.BackColor = $form.BackColor
        }
    }
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
    New-Object Drawing.Size(350,300)

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
        12,
        (66 + ($index * 18))
    )
    $dashboardMetricLabels[$index].Size = New-Object Drawing.Size(320,18)
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
        12,
        (180 + ($index * 18))
    )
    $credentialStatusLabels[$index].Size = New-Object Drawing.Size(320,18)
    $credentialStatusLabels[$index].AutoEllipsis = $true
    $grpDashboard.Controls.Add($credentialStatusLabels[$index])
}

$lblDashUser.Visible = $false
$lblDashEnv.Visible = $false
$lblDashApps.Location = New-Object Drawing.Point(12,28)
$lblDashApps.Size = New-Object Drawing.Size(155,19)
$lblDashApps.AutoEllipsis = $true
$lblDashProjects.Location = New-Object Drawing.Point(175,28)
$lblDashProjects.Size = New-Object Drawing.Size(155,19)
$lblDashProjects.AutoEllipsis = $true
$lblDashFav.Location = New-Object Drawing.Point(12,50)
$lblDashFav.Size = New-Object Drawing.Size(155,19)
$lblDashFav.AutoEllipsis = $true
$lblDashScan.Location = New-Object Drawing.Point(175,50)
$lblDashScan.Size = New-Object Drawing.Size(155,19)
$lblDashScan.AutoEllipsis = $true

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

        Start-AppLauncherApplication `
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

        Start-AppLauncherApplication `
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

        Start-AppLauncherApplication `
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

        Start-AppLauncherApplication `
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
    $dialog.Filter = "Perfil APPLauncher (*.profile.zip)|*.profile.zip"
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
    $dialog.Filter = "Perfil APPLauncher (*.profile.zip)|*.profile.zip|ZIP (*.zip)|*.zip"
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

function Invoke-LauncherUpdate {

    $settings = Get-JsonFile "settings.json"
    $updateSource = [string]$settings.updateSource

    if([string]::IsNullOrWhiteSpace($updateSource)){
        Set-LauncherUpdateSource
        $settings = Get-JsonFile "settings.json"
        $updateSource = [string]$settings.updateSource
        if([string]::IsNullOrWhiteSpace($updateSource)){
            return
        }
    }

    $preparedUpdate = $null
    $handoffStarted = $false
    try{
        $release = Get-LauncherUpdateRelease -UpdateSource $updateSource
        if(-not $release.IsUpdateAvailable){
            Show-Info "El Launcher está actualizado. Versión instalada: $($release.CurrentVersion.ToString(3)); versión disponible: $($release.VersionText)."
            return
        }

        $confirmation = [System.Windows.Forms.MessageBox]::Show(
            "Hay una actualización disponible ($($release.VersionText)). La versión instalada es $($release.CurrentVersion.ToString(3)). Se respaldarán los archivos reemplazados y el Launcher se reiniciará. ¿Desea instalarla ahora?",
            "Actualización disponible",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        if($confirmation -ne [System.Windows.Forms.DialogResult]::Yes){
            return
        }

        $preparedUpdate = Expand-VerifiedLauncherUpdate -Release $release
        Start-LauncherUpdate `
            -PreparedUpdate $preparedUpdate `
            -InstallRoot $Root | Out-Null
        $handoffStarted = $true
        $form.Close()
    }
    catch{
        Show-Error $_.Exception.Message
    }
    finally{
        if(
            -not $handoffStarted -and
            $null -ne $preparedUpdate -and
            (Test-Path -LiteralPath $preparedUpdate.TemporaryRoot)
        ){
            Remove-Item -LiteralPath $preparedUpdate.TemporaryRoot -Recurse -Force
        }
    }
}

$btnCheckUpdates = New-Object System.Windows.Forms.Button
$btnCheckUpdates.Text = "Buscar actualizaciones"
$btnCheckUpdates.Location = New-Object Drawing.Point(790,390)
$btnCheckUpdates.Size = New-Object Drawing.Size(140,40)
$btnCheckUpdates.Add_Click({
    Invoke-Safely {
        Invoke-LauncherUpdate
    }
})
$form.Controls.Add($btnCheckUpdates)

function Set-LauncherUpdateSource {

    $settings = Get-JsonFile "settings.json"
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Seleccione la carpeta compartida que contiene version.json y los paquetes del Launcher."
    $currentUpdateSource = [string]$settings.updateSource
    if(
        -not [string]::IsNullOrWhiteSpace($currentUpdateSource) -and
        (Test-Path -LiteralPath $currentUpdateSource -PathType Container)
    ){
        $dialog.SelectedPath = $currentUpdateSource
    }

    if($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK){
        if($settings.PSObject.Properties["updateSource"]){
            $settings.updateSource = $dialog.SelectedPath
        }
        else{
            $settings | Add-Member -NotePropertyName updateSource -NotePropertyValue $dialog.SelectedPath
        }
        Save-JsonFile "settings.json" $settings
        Show-Info "Origen de actualizaciones guardado."
    }

    $dialog.Dispose()
}

$btnUpdateSource = New-Object System.Windows.Forms.Button
$btnUpdateSource.Text = "Configurar origen"
$btnUpdateSource.Location = New-Object Drawing.Point(790,445)
$btnUpdateSource.Size = New-Object Drawing.Size(140,40)
$btnUpdateSource.Add_Click({
    Invoke-Safely {
        Set-LauncherUpdateSource
    }
})
$form.Controls.Add($btnUpdateSource)

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
$grpProjects.Size = New-Object Drawing.Size(480,180)

$cmbProjectLauncher = New-Object System.Windows.Forms.ComboBox
$cmbProjectLauncher.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbProjectLauncher.DisplayMember = "name"
$cmbProjectLauncher.Location = New-Object Drawing.Point(12,34)
$cmbProjectLauncher.Size = New-Object Drawing.Size(325,28)
$cmbProjectLauncher.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top -bor
    [System.Windows.Forms.AnchorStyles]::Left -bor
    [System.Windows.Forms.AnchorStyles]::Right
)
$grpProjects.Controls.Add($cmbProjectLauncher)

$btnLaunchProject = New-Object System.Windows.Forms.Button
$btnLaunchProject.Text = "Iniciar"
$btnLaunchProject.Location = New-Object Drawing.Point(345,32)
$btnLaunchProject.Size = New-Object Drawing.Size(90,30)
$btnLaunchProject.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top -bor
    [System.Windows.Forms.AnchorStyles]::Right
)
$btnLaunchProject.Add_Click({
    if($null -eq $cmbProjectLauncher.SelectedItem){
        return
    }

    Invoke-Safely {
        Start-ProjectProfile -Project $cmbProjectLauncher.SelectedItem
        RefreshDashboard
    }
})
$grpProjects.Controls.Add($btnLaunchProject)

$lblProjectEmpty = New-Object System.Windows.Forms.Label
$lblProjectEmpty.Text = "No hay proyectos configurados."
$lblProjectEmpty.Location = New-Object Drawing.Point(14,72)
$lblProjectEmpty.AutoSize = $true
$grpProjects.Controls.Add($lblProjectEmpty)

function Refresh-ProjectLauncher {

    $selectedProjectName = ""
    if($null -ne $cmbProjectLauncher.SelectedItem){
        $selectedProjectName = [string]$cmbProjectLauncher.SelectedItem.name
    }

    $cmbProjectLauncher.Items.Clear()
    $projectDefinitions = @((Get-Projects).projects)

    foreach($project in $projectDefinitions){

        if(
            $null -eq $project -or
            [string]::IsNullOrWhiteSpace([string]$project.name)
        ){
            continue
        }

        [void]$cmbProjectLauncher.Items.Add($project)

    }

    $lblProjectEmpty.Visible = ($cmbProjectLauncher.Items.Count -eq 0)
    $btnLaunchProject.Enabled = ($cmbProjectLauncher.Items.Count -gt 0)
    if($cmbProjectLauncher.Items.Count -gt 0){
        $selectedIndex = -1
        for($index = 0; $index -lt $cmbProjectLauncher.Items.Count; $index++){
            if($cmbProjectLauncher.Items[$index].name -eq $selectedProjectName){
                $selectedIndex = $index
                break
            }
        }
        if($selectedIndex -lt 0){ $selectedIndex = 0 }
        $cmbProjectLauncher.SelectedIndex = $selectedIndex

    }

}

Refresh-ProjectLauncher

# ==================================
# QUICK LINKS
# ==================================

$grpQuickLinks = New-Object System.Windows.Forms.GroupBox
$grpQuickLinks.Text = "Accesos web"
$grpQuickLinks.Size = New-Object Drawing.Size(480,150)

$cmbQuickLinksMain = New-Object System.Windows.Forms.ComboBox
$cmbQuickLinksMain.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbQuickLinksMain.DisplayMember = "name"
$cmbQuickLinksMain.Location = New-Object Drawing.Point(12,34)
$cmbQuickLinksMain.Size = New-Object Drawing.Size(320,28)
$cmbQuickLinksMain.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top -bor
    [System.Windows.Forms.AnchorStyles]::Left -bor
    [System.Windows.Forms.AnchorStyles]::Right
)
$grpQuickLinks.Controls.Add($cmbQuickLinksMain)

$btnOpenQuickLink = New-Object System.Windows.Forms.Button
$btnOpenQuickLink.Text = "Abrir"
$btnOpenQuickLink.Location = New-Object Drawing.Point(340,32)
$btnOpenQuickLink.Size = New-Object Drawing.Size(90,30)
$btnOpenQuickLink.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top -bor
    [System.Windows.Forms.AnchorStyles]::Right
)
$btnOpenQuickLink.Add_Click({
    if($null -eq $cmbQuickLinksMain.SelectedItem){
        return
    }

    Invoke-Safely {
        Open-QuickLink -Link $cmbQuickLinksMain.SelectedItem
    }
})
$grpQuickLinks.Controls.Add($btnOpenQuickLink)

$lblQuickLinksEmpty = New-Object System.Windows.Forms.Label
$lblQuickLinksEmpty.Text = "No hay accesos web configurados."
$lblQuickLinksEmpty.Location = New-Object Drawing.Point(14,72)
$lblQuickLinksEmpty.AutoSize = $true
$grpQuickLinks.Controls.Add($lblQuickLinksEmpty)

$btnManageQuickLinks = New-Object System.Windows.Forms.Button
$btnManageQuickLinks.Text = "Administrar accesos web"
$btnManageQuickLinks.Location = New-Object Drawing.Point(12,108)
$btnManageQuickLinks.Size = New-Object Drawing.Size(418,30)
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

    $selectedUrl = ""
    if($null -ne $cmbQuickLinksMain.SelectedItem){
        $selectedUrl = [string]$cmbQuickLinksMain.SelectedItem.url
    }

    $cmbQuickLinksMain.Items.Clear()
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

        [void]$cmbQuickLinksMain.Items.Add($validatedLink)
    }

    $lblQuickLinksEmpty.Text = if($invalidLinks -gt 0){
        "Revise enlaces inválidos en Administrar."
    }
    else{
        "No hay accesos web configurados."
    }

    $lblQuickLinksEmpty.Visible = ($cmbQuickLinksMain.Items.Count -eq 0)
    $btnOpenQuickLink.Enabled = ($cmbQuickLinksMain.Items.Count -gt 0)
    if($cmbQuickLinksMain.Items.Count -gt 0){
        $selectedIndex = -1
        for($index = 0; $index -lt $cmbQuickLinksMain.Items.Count; $index++){
            if($cmbQuickLinksMain.Items[$index].url -eq $selectedUrl){
                $selectedIndex = $index
                break
            }
        }
        if($selectedIndex -lt 0){ $selectedIndex = 0 }
        $cmbQuickLinksMain.SelectedIndex = $selectedIndex
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

function Set-LauncherCompactLayout {

    $form.SuspendLayout()
    $form.Controls.Clear()
    $form.AutoScroll = $false

    $mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $mainLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainLayout.Padding = New-Object System.Windows.Forms.Padding(8)
    $mainLayout.ColumnCount = 1
    $mainLayout.RowCount = 4
    [void]$mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle(
        [System.Windows.Forms.SizeType]::Percent,
        100
    )))
    [void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Absolute,
        62
    )))
    [void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Absolute,
        108
    )))
    [void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Percent,
        100
    )))
    [void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Absolute,
        68
    )))

    $headerLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $headerLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $headerLayout.Margin = New-Object System.Windows.Forms.Padding(0,0,0,4)
    $headerLayout.ColumnCount = 4
    $headerLayout.RowCount = 1
    foreach($columnWidth in @(40, 30, 20, 10)){
        [void]$headerLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle(
            [System.Windows.Forms.SizeType]::Percent,
            $columnWidth
        )))
    }
    [void]$headerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Percent,
        100
    )))

    $userHeader = New-Object System.Windows.Forms.Panel
    $userHeader.Dock = [System.Windows.Forms.DockStyle]::Fill
    $lblUser.Location = New-Object Drawing.Point(4,2)
    $cmbUser.Location = New-Object Drawing.Point(4,23)
    $cmbUser.Size = New-Object Drawing.Size(185,28)
    $btnUsers.Text = "Usuarios"
    $btnUsers.Location = New-Object Drawing.Point(195,22)
    $btnUsers.Size = New-Object Drawing.Size(100,30)
    $userHeader.Controls.AddRange(@($lblUser, $cmbUser, $btnUsers))

    $grpEnv.Dock = [System.Windows.Forms.DockStyle]::Fill
    $grpEnv.Margin = New-Object System.Windows.Forms.Padding(3,0,3,0)
    $grpEnv.Size = New-Object Drawing.Size(260,58)

    $environmentHeader = New-Object System.Windows.Forms.Panel
    $environmentHeader.Dock = [System.Windows.Forms.DockStyle]::Fill
    $lblEnvironment.Location = New-Object Drawing.Point(4,24)
    $lblEnvironment.Size = New-Object Drawing.Size(150,22)
    $lblEnvironment.AutoEllipsis = $true
    $environmentHeader.Controls.Add($lblEnvironment)

    $exitHeader = New-Object System.Windows.Forms.Panel
    $exitHeader.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnExit.Location = New-Object Drawing.Point(2,20)
    $btnExit.Size = New-Object Drawing.Size(78,30)
    $exitHeader.Controls.Add($btnExit)

    $headerLayout.Controls.Add($userHeader, 0, 0)
    $headerLayout.Controls.Add($grpEnv, 1, 0)
    $headerLayout.Controls.Add($environmentHeader, 2, 0)
    $headerLayout.Controls.Add($exitHeader, 3, 0)

    $grpApplications = New-Object System.Windows.Forms.GroupBox
    $grpApplications.Text = "Iniciar aplicación"
    $grpApplications.Dock = [System.Windows.Forms.DockStyle]::Fill
    $grpApplications.Margin = New-Object System.Windows.Forms.Padding(0,0,0,4)

    $applicationLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $applicationLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $applicationLayout.Padding = New-Object System.Windows.Forms.Padding(4,6,4,2)
    $applicationLayout.ColumnCount = 4
    $applicationLayout.RowCount = 1
    foreach($columnWidth in @(25,25,25,25)){
        [void]$applicationLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle(
            [System.Windows.Forms.SizeType]::Percent,
            $columnWidth
        )))
    }
    [void]$applicationLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Percent,
        100
    )))

    $applicationButtons = @($btnSSMS, $btnVS, $btnCode, $btnReport)
    for($index = 0; $index -lt $applicationButtons.Count; $index++){
        $applicationButtons[$index].Dock = [System.Windows.Forms.DockStyle]::Fill
        $applicationButtons[$index].Margin = New-Object System.Windows.Forms.Padding(4)
        $applicationButtons[$index].AutoEllipsis = $true
        $applicationLayout.Controls.Add($applicationButtons[$index], $index, 0)
    }
    $grpApplications.Controls.Add($applicationLayout)

    $grpProjects.Controls.Clear()
    $projectActionLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $projectActionLayout.Dock = [System.Windows.Forms.DockStyle]::Top
    $projectActionLayout.Location = New-Object Drawing.Point(8,24)
    $projectActionLayout.Height = 40
    $projectActionLayout.ColumnCount = 2
    $projectActionLayout.RowCount = 1
    [void]$projectActionLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle(
        [System.Windows.Forms.SizeType]::Percent,
        78
    )))
    [void]$projectActionLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle(
        [System.Windows.Forms.SizeType]::Percent,
        22
    )))
    [void]$projectActionLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Percent,
        100
    )))
    $cmbProjectLauncher.Dock = [System.Windows.Forms.DockStyle]::Fill
    $cmbProjectLauncher.Margin = New-Object System.Windows.Forms.Padding(2)
    $btnLaunchProject.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnLaunchProject.Margin = New-Object System.Windows.Forms.Padding(2)
    $projectActionLayout.Controls.Add($cmbProjectLauncher, 0, 0)
    $projectActionLayout.Controls.Add($btnLaunchProject, 1, 0)
    $lblProjectEmpty.Location = New-Object Drawing.Point(12,72)
    $grpProjects.Controls.Add($projectActionLayout)
    $grpProjects.Controls.Add($lblProjectEmpty)

    $grpQuickLinks.Controls.Clear()
    $quickLinkActionLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $quickLinkActionLayout.Dock = [System.Windows.Forms.DockStyle]::Top
    $quickLinkActionLayout.Location = New-Object Drawing.Point(8,24)
    $quickLinkActionLayout.Height = 40
    $quickLinkActionLayout.ColumnCount = 2
    $quickLinkActionLayout.RowCount = 1
    [void]$quickLinkActionLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle(
        [System.Windows.Forms.SizeType]::Percent,
        78
    )))
    [void]$quickLinkActionLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle(
        [System.Windows.Forms.SizeType]::Percent,
        22
    )))
    [void]$quickLinkActionLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Percent,
        100
    )))
    $cmbQuickLinksMain.Dock = [System.Windows.Forms.DockStyle]::Fill
    $cmbQuickLinksMain.Margin = New-Object System.Windows.Forms.Padding(2)
    $btnOpenQuickLink.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnOpenQuickLink.Margin = New-Object System.Windows.Forms.Padding(2)
    $quickLinkActionLayout.Controls.Add($cmbQuickLinksMain, 0, 0)
    $quickLinkActionLayout.Controls.Add($btnOpenQuickLink, 1, 0)
    $lblQuickLinksEmpty.Location = New-Object Drawing.Point(12,68)
    $btnManageQuickLinks.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $btnManageQuickLinks.Height = 30
    $btnManageQuickLinks.Margin = New-Object System.Windows.Forms.Padding(2)
    $grpQuickLinks.Controls.Add($quickLinkActionLayout)
    $grpQuickLinks.Controls.Add($lblQuickLinksEmpty)
    $grpQuickLinks.Controls.Add($btnManageQuickLinks)

    $grpFavoritesMain = New-Object System.Windows.Forms.GroupBox
    $grpFavoritesMain.Text = "Favoritos"
    $grpFavoritesMain.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnFav.Text = "Administrar favoritos"
    $btnFav.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnFav.Margin = New-Object System.Windows.Forms.Padding(6)
    $grpFavoritesMain.Controls.Add($btnFav)

    $leftStack = New-Object System.Windows.Forms.TableLayoutPanel
    $leftStack.Dock = [System.Windows.Forms.DockStyle]::Fill
    $leftStack.Padding = New-Object System.Windows.Forms.Padding(0,0,4,0)
    $leftStack.ColumnCount = 1
    $leftStack.RowCount = 3
    foreach($rowHeight in @(42, 34, 24)){
        [void]$leftStack.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
            [System.Windows.Forms.SizeType]::Percent,
            $rowHeight
        )))
    }
    $grpProjects.Dock = [System.Windows.Forms.DockStyle]::Fill
    $grpProjects.Margin = New-Object System.Windows.Forms.Padding(0,0,0,4)
    $grpQuickLinks.Dock = [System.Windows.Forms.DockStyle]::Fill
    $grpQuickLinks.Margin = New-Object System.Windows.Forms.Padding(0,0,0,4)
    $grpFavoritesMain.Margin = New-Object System.Windows.Forms.Padding(0)
    $leftStack.Controls.Add($grpProjects, 0, 0)
    $leftStack.Controls.Add($grpQuickLinks, 0, 1)
    $leftStack.Controls.Add($grpFavoritesMain, 0, 2)

    $grpManagement = New-Object System.Windows.Forms.GroupBox
    $grpManagement.Text = "Administrar"
    $grpManagement.Dock = [System.Windows.Forms.DockStyle]::Fill

    $managementLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $managementLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $managementLayout.Padding = New-Object System.Windows.Forms.Padding(4,5,4,3)
    $managementLayout.ColumnCount = 2
    $managementLayout.RowCount = 4
    foreach($columnWidth in @(50,50)){
        [void]$managementLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle(
            [System.Windows.Forms.SizeType]::Percent,
            $columnWidth
        )))
    }
    foreach($rowHeight in @(25,25,25,25)){
        [void]$managementLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
            [System.Windows.Forms.SizeType]::Percent,
            $rowHeight
        )))
    }
    $managementButtons = @(
        $btnCreds,
        $btnProjectsManager,
        $btnLogs,
        $btnExportProfile,
        $btnImportProfile,
        $btnCheckUpdates,
        $btnUpdateSource
    )
    $btnProjectsManager.Text = "Administrar proyectos"
    foreach($button in $managementButtons){
        $button.Dock = [System.Windows.Forms.DockStyle]::Fill
        $button.Margin = New-Object System.Windows.Forms.Padding(3)
        $button.AutoEllipsis = $true
    }
    for($index = 0; $index -lt $managementButtons.Count; $index++){
        $managementLayout.Controls.Add(
            $managementButtons[$index],
            ($index % 2),
            [Math]::Floor($index / 2)
        )
    }
    $grpManagement.Controls.Add($managementLayout)

    $rightStack = New-Object System.Windows.Forms.TableLayoutPanel
    $rightStack.Dock = [System.Windows.Forms.DockStyle]::Fill
    $rightStack.Padding = New-Object System.Windows.Forms.Padding(4,0,0,0)
    $rightStack.ColumnCount = 1
    $rightStack.RowCount = 2
    [void]$rightStack.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Percent,
        62
    )))
    [void]$rightStack.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Percent,
        38
    )))
    $grpDashboard.Dock = [System.Windows.Forms.DockStyle]::Fill
    $grpDashboard.Margin = New-Object System.Windows.Forms.Padding(0,0,0,4)
    $grpManagement.Margin = New-Object System.Windows.Forms.Padding(0)
    $rightStack.Controls.Add($grpDashboard, 0, 0)
    $rightStack.Controls.Add($grpManagement, 0, 1)

    $workspaceLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $workspaceLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $workspaceLayout.ColumnCount = 2
    $workspaceLayout.RowCount = 1
    [void]$workspaceLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle(
        [System.Windows.Forms.SizeType]::Percent,
        56
    )))
    [void]$workspaceLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle(
        [System.Windows.Forms.SizeType]::Percent,
        44
    )))
    [void]$workspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle(
        [System.Windows.Forms.SizeType]::Percent,
        100
    )))
    $workspaceLayout.Controls.Add($leftStack, 0, 0)
    $workspaceLayout.Controls.Add($rightStack, 1, 0)

    $grpStatus.Controls.Clear()
    $grpStatus.Text = "Disponibilidad"
    $grpStatus.Dock = [System.Windows.Forms.DockStyle]::Fill
    $grpStatus.Margin = New-Object System.Windows.Forms.Padding(0,4,0,0)
    $statusFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $statusFlow.Dock = [System.Windows.Forms.DockStyle]::Fill
    $statusFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $statusFlow.WrapContents = $false
    $statusFlow.AutoScroll = $true
    foreach($label in @($lblSSMSStatus, $lblVSStatus, $lblCodeStatus, $lblReportStatus)){
        $label.AutoSize = $false
        $label.Size = New-Object Drawing.Size(145,24)
        $label.AutoEllipsis = $true
        $label.Margin = New-Object System.Windows.Forms.Padding(4,8,2,2)
        $statusFlow.Controls.Add($label)
    }
    $lblSummary.AutoSize = $false
    $lblSummary.Size = New-Object Drawing.Size(105,24)
    $lblSummary.Margin = New-Object System.Windows.Forms.Padding(4,8,2,2)
    $btnScan.Text = "Reescanear"
    $btnScan.Size = New-Object Drawing.Size(105,30)
    $btnScan.Margin = New-Object System.Windows.Forms.Padding(4,4,2,2)
    $statusFlow.Controls.Add($lblSummary)
    $statusFlow.Controls.Add($btnScan)
    $grpStatus.Controls.Add($statusFlow)

    $mainLayout.Controls.Add($headerLayout, 0, 0)
    $mainLayout.Controls.Add($grpApplications, 0, 1)
    $mainLayout.Controls.Add($workspaceLayout, 0, 2)
    $mainLayout.Controls.Add($grpStatus, 0, 3)

    $script:launcherThemeSurfaces = @(
        $mainLayout,
        $headerLayout,
        $userHeader,
        $environmentHeader,
        $exitHeader,
        $grpApplications,
        $applicationLayout,
        $workspaceLayout,
        $leftStack,
        $rightStack,
        $grpProjects,
        $grpQuickLinks,
        $grpFavoritesMain,
        $grpDashboard,
        $grpManagement,
        $managementLayout,
        $grpStatus,
        $statusFlow
    )
    foreach($surface in $script:launcherThemeSurfaces){
        $surface.BackColor = $form.BackColor
    }

    $form.Controls.Add($mainLayout)
    $form.PerformLayout()
    $form.ResumeLayout($true)
    RefreshTheme
}

Set-LauncherCompactLayout

# ==================================
# SHOW
# ==================================

[void]$form.ShowDialog()