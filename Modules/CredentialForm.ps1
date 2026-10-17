function Show-CredentialForm {

    param(
        [string[]]$Users,
        [System.Windows.Forms.IWin32Window]$Owner
    )

    $formCred = New-Object System.Windows.Forms.Form

    $formCred.Text = "Administración de Credenciales"
    $formCred.Width = 650
    $formCred.Height = 500
    $formCred.StartPosition = "CenterParent"
    $formCred.MaximizeBox = $false

    $script:clipboardTimer =
    New-Object System.Windows.Forms.Timer

    $script:clipboardTimer.Interval = 60000

    $script:clipboardTimer.Add_Tick({

        try{

            [System.Windows.Forms.Clipboard]::Clear()

            $lblStatus.Text =
                "Estado: Portapapeles limpiado"

        }
        catch{
        }

        $script:clipboardTimer.Stop()

    })

    # ==================================
    # USUARIO
    # ==================================

    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = "Usuario"
    $lblUser.Location = New-Object Drawing.Point(20,20)

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

    $lblEnv = New-Object System.Windows.Forms.Label
    $lblEnv.Text = "Entorno"
    $lblEnv.Location = New-Object Drawing.Point(20,95)

    $formCred.Controls.Add($lblEnv)

    $cmbEnv = New-Object System.Windows.Forms.ComboBox
    $cmbEnv.Location = New-Object Drawing.Point(20,120)
    $cmbEnv.Width = 250

    @(
        "DEV",
        "QC",
        "PROD"
    ) | ForEach-Object {

        [void]$cmbEnv.Items.Add($_)

    }

    $cmbEnv.SelectedIndex = 0

    $formCred.Controls.Add($cmbEnv)

    # ==================================
    # PASSWORD
    # ==================================

    $lblPassword = New-Object System.Windows.Forms.Label
    $lblPassword.Text = "Contraseña"
    $lblPassword.Location = New-Object Drawing.Point(20,170)

    $formCred.Controls.Add($lblPassword)

    $txtPassword = New-Object System.Windows.Forms.TextBox
    $txtPassword.Location = New-Object Drawing.Point(20,195)
    $txtPassword.Width = 250

    $txtPassword.UseSystemPasswordChar = $true

    $formCred.Controls.Add($txtPassword)

    # ==================================
    # ESTADO
    # ==================================

    $lblStatus = New-Object System.Windows.Forms.Label

    $lblStatus.AutoSize = $true
    $lblStatus.Location = New-Object Drawing.Point(20,255)

    $lblStatus.Text =
        "Estado: Sin verificar"

    $formCred.Controls.Add($lblStatus)

    # ==================================
    # GUARDAR
    # ==================================

    $btnSave = New-Object System.Windows.Forms.Button

    $btnSave.Text = "Guardar"
    $btnSave.Location = New-Object Drawing.Point(330,30)
    $btnSave.Size = New-Object Drawing.Size(250,40)

    $btnSave.Add_Click({

        if(
            [string]::IsNullOrWhiteSpace(
                $cmbUser.Text
            )
        ){
            Show-Error "Seleccione un usuario."
            return
        }

        if(
            [string]::IsNullOrWhiteSpace(
                $txtPassword.Text
            )
        ){
            Show-Error "Ingrese una contraseña."
            return
        }

        try{

            Save-LauncherCredential `
                $cmbEnv.Text `
                $cmbUser.Text `
                $txtPassword.Text

            $txtPassword.Clear()

            $lblStatus.Text =
                "Estado: Credencial guardada"

            Show-Info "Credencial almacenada."

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formCred.Controls.Add($btnSave)

    # ==================================
    # VERIFICAR
    # ==================================

    $btnVerify = New-Object System.Windows.Forms.Button

    $btnVerify.Text = "Verificar"
    $btnVerify.Location = New-Object Drawing.Point(330,85)
    $btnVerify.Size = New-Object Drawing.Size(250,40)

    $btnVerify.Add_Click({

        try{

            $credentialStatus =
                Get-LauncherCredentialStatus `
                    $cmbEnv.Text `
                    $cmbUser.Text

            $lblStatus.Text =
                "Estado: " + $credentialStatus.Status

            if($credentialStatus.Status -eq "Expirada"){

                Remove-ExpiredLauncherCredentials | Out-Null

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
    $btnDelete.Location = New-Object Drawing.Point(330,140)
    $btnDelete.Size = New-Object Drawing.Size(250,40)

    $btnDelete.Add_Click({

        try{

            Remove-LauncherCredential `
                $cmbEnv.Text `
                $cmbUser.Text

            $lblStatus.Text =
                "Estado: Credencial eliminada"

            Show-Info "Credencial eliminada."

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formCred.Controls.Add($btnDelete)

    # ==================================
    # COPIAR PASSWORD
    # ==================================

    $btnCopy = New-Object System.Windows.Forms.Button

    $btnCopy.Text = "Copiar Contraseña"

    $btnCopy.Location =
        New-Object Drawing.Point(330,195)

    $btnCopy.Size =
        New-Object Drawing.Size(250,40)

    $btnCopy.Add_Click({

        try{

            Copy-LauncherCredentialToClipboard `
                $cmbEnv.Text `
                $cmbUser.Text

            $clipboardTimer.Stop()
            $clipboardTimer.Start()

            $formCred.Activate()

            $lblStatus.Text =
                "Estado: Contraseña copiada (60 seg)"

            Show-Info @"
La contraseña fue copiada al portapapeles.
 
Se eliminará automáticamente en 60 segundos.
"@

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formCred.Controls.Add($btnCopy)

    # ==================================
    # CERRAR
    # ==================================

    $btnClose = New-Object System.Windows.Forms.Button

    $btnClose.Text = "Cerrar"
    $btnClose.Location = New-Object Drawing.Point(330,310)
    $btnClose.Size = New-Object Drawing.Size(250,40)

    $btnClose.Add_Click({

        $formCred.Close()

    })

    $formCred.Controls.Add($btnClose)

    # ==================================
    # SHOW
    # ==================================

    if($Owner){

        [void]$formCred.ShowDialog($Owner)

    }
    else{

        [void]$formCred.ShowDialog()

    }

}