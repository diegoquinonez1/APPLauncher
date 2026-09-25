function Show-CredentialForm {

    param(
        [string[]]$Users
    )

    $formCred = New-Object System.Windows.Forms.Form

    $formCred.Text = "Administración de Credenciales"
    $formCred.Width = 520
    $formCred.Height = 360
    $formCred.StartPosition = "CenterParent"
    $formCred.MaximizeBox = $false

    # ==================================
    # USUARIO
    # ==================================

    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = "Usuario"
    $lblUser.Location = New-Object Drawing.Point(20,20)
    $lblUser.AutoSize = $true

    $formCred.Controls.Add($lblUser)

    $cmbUser = New-Object System.Windows.Forms.ComboBox
    $cmbUser.Location = New-Object Drawing.Point(20,45)
    $cmbUser.Width = 250

    foreach($user in $Users){

        [void]$cmbUser.Items.Add($user)

    }

    if($cmbUser.Items.Count -gt 0){

        $cmbUser.SelectedIndex = 0

    }

    $formCred.Controls.Add($cmbUser)

    # ==================================
    # ENTORNO
    # ==================================

    $grpEnv = New-Object System.Windows.Forms.GroupBox
    $grpEnv.Text = "Entorno"
    $grpEnv.Location = New-Object Drawing.Point(20,90)
    $grpEnv.Size = New-Object Drawing.Size(250,120)

    $formCred.Controls.Add($grpEnv)

    $rbDev = New-Object System.Windows.Forms.RadioButton
    $rbDev.Text = "DEV"
    $rbDev.Checked = $true
    $rbDev.Location = New-Object Drawing.Point(20,20)

    $grpEnv.Controls.Add($rbDev)

    $rbQc = New-Object System.Windows.Forms.RadioButton
    $rbQc.Text = "QC"
    $rbQc.Location = New-Object Drawing.Point(20,50)

    $grpEnv.Controls.Add($rbQc)

    $rbProd = New-Object System.Windows.Forms.RadioButton
    $rbProd.Text = "PROD"
    $rbProd.Location = New-Object Drawing.Point(20,80)

    $grpEnv.Controls.Add($rbProd)

    function Get-CredentialEnvironment {

        if($rbDev.Checked){
            return "DEV"
        }

        if($rbQc.Checked){
            return "QC"
        }

        return "PROD"
    }

    # ==================================
    # ESTADO
    # ==================================

    $lblStatus = New-Object System.Windows.Forms.Label

    $lblStatus.Location = New-Object Drawing.Point(20,240)
    $lblStatus.AutoSize = $true
    $lblStatus.Text = "Estado: Sin verificar"

    $formCred.Controls.Add($lblStatus)

    # ==================================
    # AGREGAR
    # ==================================

    $btnAdd = New-Object System.Windows.Forms.Button

    $btnAdd.Text = "Agregar"
    $btnAdd.Location = New-Object Drawing.Point(300,30)
    $btnAdd.Size = New-Object Drawing.Size(170,35)

    $btnAdd.Add_Click({

        $password =
        [Microsoft.VisualBasic.Interaction]::InputBox(
            "Ingrese la contraseña",
            "Agregar credencial"
        )

        if([string]::IsNullOrWhiteSpace($password)){
            return
        }

        try{

            Add-LauncherCredential `
                (Get-CredentialEnvironment) `
                $cmbUser.Text `
                $password

            $lblStatus.Text =
                "Estado: Credencial agregada"

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formCred.Controls.Add($btnAdd)

    # ==================================
    # VERIFICAR
    # ==================================

    $btnVerify = New-Object System.Windows.Forms.Button

    $btnVerify.Text = "Verificar"
    $btnVerify.Location = New-Object Drawing.Point(300,80)
    $btnVerify.Size = New-Object Drawing.Size(170,35)

    $btnVerify.Add_Click({

        try{

            $exists =
                Test-LauncherCredential `
                    (Get-CredentialEnvironment) `
                    $cmbUser.Text

            if($exists){

                $lblStatus.Text =
                    "Estado: Configurada"

            }
            else{

                $lblStatus.Text =
                    "Estado: No encontrada"

            }

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formCred.Controls.Add($btnVerify)

    # ==================================
    # ELIMINAR
    # ==================================

    $btnDelete = New-Object System.Windows.Forms.Button

    $btnDelete.Text = "Eliminar"
    $btnDelete.Location = New-Object Drawing.Point(300,130)
    $btnDelete.Size = New-Object Drawing.Size(170,35)

    $btnDelete.Add_Click({

        try{

            Remove-LauncherCredential `
                (Get-CredentialEnvironment) `
                $cmbUser.Text

            $lblStatus.Text =
                "Estado: Credencial eliminada"

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formCred.Controls.Add($btnDelete)

    # ============================= LISTAR CMDKEY
    # ==================================

    $btnList = New-Object System.Windows.Forms.Button

    $btnList.Text = "Ver todas"
    $btnList.Location = New-Object Drawing.Point(300,180)
    $btnList.Size = New-Object Drawing.Size(170,35)

    $btnList.Add_Click({

        Start-Process cmd.exe `
            "/k cmdkey /list"

    })

    $formCred.Controls.Add($btnList)

    # ==================================
    # MOSTRAR
    # ==================================

    [void]$formCred.ShowDialog()
}