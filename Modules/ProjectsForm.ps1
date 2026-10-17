function Show-ProjectsForm {

    $formProjects = New-Object System.Windows.Forms.Form
    $formProjects.Text = "Administración de Proyectos"
    $formProjects.Width = 980
    $formProjects.Height = 620
    $formProjects.StartPosition = "CenterParent"
    $formProjects.MaximizeBox = $false

    # ==================================
    # LISTA
    # ==================================

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object Drawing.Point(20,20)
    $list.Size = New-Object Drawing.Size(300,440)
    $formProjects.Controls.Add($list)

    # ==================================
    # NOMBRE
    # ==================================

    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Text = "Nombre"
    $lblName.Location = New-Object Drawing.Point(350,20)
    $formProjects.Controls.Add($lblName)

    $txtName = New-Object System.Windows.Forms.TextBox
    $txtName.Location = New-Object Drawing.Point(350,45)
    $txtName.Width = 260
    $formProjects.Controls.Add($txtName)

    # ==================================
    # ENTORNO
    # ==================================

    $lblEnv = New-Object System.Windows.Forms.Label
    $lblEnv.Text = "Entorno"
    $lblEnv.Location = New-Object Drawing.Point(640,20)
    $formProjects.Controls.Add($lblEnv)

    $cmbEnv = New-Object System.Windows.Forms.ComboBox
    $cmbEnv.Location = New-Object Drawing.Point(640,45)
    $cmbEnv.Width = 200
    @("DEV","QC","PROD") |
    ForEach-Object {
        [void]$cmbEnv.Items.Add($_)
    }
    $formProjects.Controls.Add($cmbEnv)

    # ==================================
    # USUARIO
    # ==================================

    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = "Usuario"
    $lblUser.Location = New-Object Drawing.Point(350,95)
    $formProjects.Controls.Add($lblUser)

    $cmbUser = New-Object System.Windows.Forms.ComboBox
    $cmbUser.Location = New-Object Drawing.Point(350,120)
    $cmbUser.Width = 240
    (Get-Users).users |
    ForEach-Object {
        if(-not [string]::IsNullOrWhiteSpace($_)){
            [void]$cmbUser.Items.Add($_)
        }
    }
    $formProjects.Controls.Add($cmbUser)

    # ==================================
    # SOLUCIÓN
    # ==================================

    $lblSolution = New-Object System.Windows.Forms.Label
    $lblSolution.Text = "Solución (.sln)"
    $lblSolution.Location = New-Object Drawing.Point(350,170)
    $formProjects.Controls.Add($lblSolution)

    $txtSolution = New-Object System.Windows.Forms.TextBox
    $txtSolution.Location = New-Object Drawing.Point(350,195)
    $txtSolution.Width = 430
    $formProjects.Controls.Add($txtSolution)

    $btnBrowseSolution = New-Object System.Windows.Forms.Button
    $btnBrowseSolution.Text = "Buscar"
    $btnBrowseSolution.Location = New-Object Drawing.Point(790,190)
    $btnBrowseSolution.Size = New-Object Drawing.Size(90,30)
    $btnBrowseSolution.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = "Soluciones (*.sln)|*.sln|Todos (*.*)|*.*"
        $dialog.Title = "Seleccionar solución"
        if($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            $txtSolution.Text = $dialog.FileName
        }
    })
    $formProjects.Controls.Add($btnBrowseSolution)

    # ==================================
    # CARPETA
    # ==================================

    $lblFolder = New-Object System.Windows.Forms.Label
    $lblFolder.Text = "Carpeta de trabajo"
    $lblFolder.Location = New-Object Drawing.Point(350,245)
    $formProjects.Controls.Add($lblFolder)

    $txtFolder = New-Object System.Windows.Forms.TextBox
    $txtFolder.Location = New-Object Drawing.Point(350,270)
    $txtFolder.Width = 430
    $formProjects.Controls.Add($txtFolder)

    $btnBrowseFolder = New-Object System.Windows.Forms.Button
    $btnBrowseFolder.Text = "Buscar"
    $btnBrowseFolder.Location = New-Object Drawing.Point(790,265)
    $btnBrowseFolder.Size = New-Object Drawing.Size(90,30)
    $btnBrowseFolder.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = "Seleccionar carpeta del proyecto"
        if($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            $txtFolder.Text = $dialog.SelectedPath
        }
    })
    $formProjects.Controls.Add($btnBrowseFolder)

    # ==================================
    # APLICACIONES DE ARRANQUE
    # ==================================

    $grpApps = New-Object System.Windows.Forms.GroupBox
    $grpApps.Text = "Aplicaciones de inicio"
    $grpApps.Location = New-Object Drawing.Point(350,320)
    $grpApps.Size = New-Object Drawing.Size(500,130)
    $formProjects.Controls.Add($grpApps)

    $cbSSMS = New-Object System.Windows.Forms.CheckBox
    $cbSSMS.Text = "SSMS"
    $cbSSMS.Location = New-Object Drawing.Point(20,25)
    $cbSSMS.Checked = $true
    $grpApps.Controls.Add($cbSSMS)

    $cbVS = New-Object System.Windows.Forms.CheckBox
    $cbVS.Text = "VisualStudio"
    $cbVS.Location = New-Object Drawing.Point(140,25)
    $cbVS.Checked = $true
    $grpApps.Controls.Add($cbVS)

    $cbCode = New-Object System.Windows.Forms.CheckBox
    $cbCode.Text = "VSCode"
    $cbCode.Location = New-Object Drawing.Point(260,25)
    $cbCode.Checked = $true
    $grpApps.Controls.Add($cbCode)

    $cbReport = New-Object System.Windows.Forms.CheckBox
    $cbReport.Text = "ReportBuilder"
    $cbReport.Location = New-Object Drawing.Point(360,25)
    $cbReport.Checked = $false
    $grpApps.Controls.Add($cbReport)

    # ==================================
    # REFRESH
    # ==================================

    function Refresh-ProjectsList {

        $list.Items.Clear()

        (Get-Projects).projects |
        ForEach-Object {

            if(
                $null -ne $_ -and
                -not [string]::IsNullOrWhiteSpace($_.name)
            ){
                [void]$list.Items.Add($_.name)
            }
        }
    }

    function Get-SelectedAppList {

        $apps = @()

        if($cbSSMS.Checked){ $apps += "SSMS" }
        if($cbVS.Checked){ $apps += "VisualStudio" }
        if($cbCode.Checked){ $apps += "VSCode" }
        if($cbReport.Checked){ $apps += "ReportBuilder" }

        return $apps
    }

    function Clear-ProjectForm {

        $txtName.Clear()
        $cmbEnv.SelectedIndex = -1
        $cmbUser.SelectedIndex = -1
        $txtSolution.Clear()
        $txtFolder.Clear()
        $cbSSMS.Checked = $true
        $cbVS.Checked = $true
        $cbCode.Checked = $true
        $cbReport.Checked = $false
        $list.ClearSelected()
    }

    Refresh-ProjectsList

    # ==================================
    # CARGAR DETALLE
    # ==================================

    $list.Add_SelectedIndexChanged({

        if($null -eq $list.SelectedItem){
            return
        }

        $selectedName = $list.SelectedItem.ToString()
        $project = @(
            (Get-Projects).projects |
            Where-Object {
                $_.name -eq $selectedName
            }
        )

        if($project.Count -eq 0){
            return
        }

        $project = $project[0]

        $txtName.Text = $project.name
        $cmbEnv.Text = $project.environment
        $cmbUser.Text = $project.user
        $txtSolution.Text = [string]$project.solution
        $txtFolder.Text = [string]$project.folder

        $cbSSMS.Checked = ($project.startupApps -contains "SSMS")
        $cbVS.Checked = ($project.startupApps -contains "VisualStudio")
        $cbCode.Checked = ($project.startupApps -contains "VSCode")
        $cbReport.Checked = ($project.startupApps -contains "ReportBuilder")
    })

    # ==================================
    # NUEVO
    # ==================================

    $btnNew = New-Object System.Windows.Forms.Button
    $btnNew.Text = "Nuevo"
    $btnNew.Location = New-Object Drawing.Point(350,470)
    $btnNew.Size = New-Object Drawing.Size(120,35)
    $btnNew.Add_Click({
        Clear-ProjectForm
    })
    $formProjects.Controls.Add($btnNew)

    # ==================================
    # GUARDAR
    # ==================================

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Guardar"
    $btnSave.Location = New-Object Drawing.Point(490,470)
    $btnSave.Size = New-Object Drawing.Size(120,35)
    $btnSave.Add_Click({

        $projectName = $txtName.Text.Trim()
        $environment = $cmbEnv.Text.Trim()
        $user = $cmbUser.Text.Trim()
        $solution = $txtSolution.Text.Trim()
        $folder = $txtFolder.Text.Trim()
        $startupApps = Get-SelectedAppList

        if([string]::IsNullOrWhiteSpace($projectName)){
            Show-Error "El nombre del proyecto es obligatorio."
            return
        }

        if([string]::IsNullOrWhiteSpace($environment)){
            Show-Error "Seleccione un entorno."
            return
        }

        if([string]::IsNullOrWhiteSpace($user)){
            Show-Error "Seleccione un usuario."
            return
        }

        if(
            $startupApps.Count -eq 0 -and
            [string]::IsNullOrWhiteSpace($solution) -and
            [string]::IsNullOrWhiteSpace($folder)
        ){
            Show-Error "Debe configurar al menos una aplicación, una solución o una carpeta."
            return
        }

        if(
            $startupApps.Count -gt 0 -and
            (
                [string]::IsNullOrWhiteSpace($environment) -or
                [string]::IsNullOrWhiteSpace($user)
            )
        ){
            Show-Error "Los perfiles con aplicaciones deben tener entorno y usuario."
            return
        }

        $selectedOriginalName = $null
        if($null -ne $list.SelectedItem){
            $selectedOriginalName = $list.SelectedItem.ToString()
        }

        try{

            if([string]::IsNullOrWhiteSpace($selectedOriginalName)){

                Add-Project `
                    -Name $projectName `
                    -Environment $environment `
                    -User $user `
                    -Solution $solution `
                    -Folder $folder `
                    -StartupApps $startupApps

            }
            else{

                Update-Project `
                    -OriginalName $selectedOriginalName `
                    -Name $projectName `
                    -Environment $environment `
                    -User $user `
                    -Solution $solution `
                    -Folder $folder `
                    -StartupApps $startupApps

            }

            Refresh-ProjectsList
            Clear-ProjectForm

            if(Get-Command Refresh-ProjectLauncher -ErrorAction SilentlyContinue){
                Refresh-ProjectLauncher
            }

            Show-Info "Proyecto guardado."

        }
        catch{
            Show-Error $_.Exception.Message
        }

    })
    $formProjects.Controls.Add($btnSave)

    # ==================================
    # ELIMINAR
    # ==================================

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "Eliminar"
    $btnDelete.Location = New-Object Drawing.Point(630,470)
    $btnDelete.Size = New-Object Drawing.Size(120,35)
    $btnDelete.Add_Click({

        if($null -eq $list.SelectedItem){
            Show-Error "Seleccione un proyecto para eliminar."
            return
        }

        try{

            Remove-Project -Name $list.SelectedItem.ToString()
            Refresh-ProjectsList
            Clear-ProjectForm

            if(Get-Command Refresh-ProjectLauncher -ErrorAction SilentlyContinue){
                Refresh-ProjectLauncher
            }

            Show-Info "Proyecto eliminado."

        }
        catch{
            Show-Error $_.Exception.Message
        }

    })
    $formProjects.Controls.Add($btnDelete)

    # ==================================
    # CERRAR
    # ==================================

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Cerrar"
    $btnClose.Location = New-Object Drawing.Point(770,470)
    $btnClose.Size = New-Object Drawing.Size(120,35)
    $btnClose.Add_Click({
        $formProjects.Close()
    })
    $formProjects.Controls.Add($btnClose)

    # ==================================
    # SHOW
    # ==================================

    [void]$formProjects.ShowDialog()
}
