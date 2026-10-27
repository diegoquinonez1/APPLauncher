function Show-UsersForm {

    param(
        [System.Windows.Forms.ComboBox]$MainUserCombo
    )

    $formUsers = New-Object System.Windows.Forms.Form

    $formUsers.Text = "Administración de Usuarios"
    $formUsers.Width = 650
    $formUsers.Height = 450
    $formUsers.StartPosition = "CenterParent"
    $formUsers.MaximizeBox = $false

    # ==================================
    # LISTA
    # ==================================

    $list = New-Object System.Windows.Forms.ListBox

    $list.Location = New-Object Drawing.Point(20,20)
    $list.Size = New-Object Drawing.Size(250,320)

    $formUsers.Controls.Add($list)

    # ==================================
    # USUARIO
    # ==================================

    $lblUser = New-Object System.Windows.Forms.Label

    $lblUser.Text = "Usuario"
    $lblUser.Location = New-Object Drawing.Point(320,30)

    $formUsers.Controls.Add($lblUser)

    $txtUser = New-Object System.Windows.Forms.TextBox

    $txtUser.Location = New-Object Drawing.Point(320,55)
    $txtUser.Width = 250

    $formUsers.Controls.Add($txtUser)

    # ==================================
    # REFRESH
    # ==================================

    function Refresh-Users {

        $list.Items.Clear()

        $users = Get-Users

        foreach($user in $users.users){

            [void]$list.Items.Add($user)

        }
    }

    function Refresh-MainCombo {

        $MainUserCombo.Items.Clear()

        (Get-Users).users |
        ForEach-Object {

            [void]$MainUserCombo.Items.Add($_)

        }
    }

    Refresh-Users

    # ==================================
    # CARGAR DETALLE
    # ==================================

    $list.Add_SelectedIndexChanged({

        if($null -eq $list.SelectedItem){
            return
        }

        $txtUser.Text =
            $list.SelectedItem.ToString()

    })

    # ==================================
    # NUEVO
    # ==================================

    $btnNew = New-Object System.Windows.Forms.Button

    $btnNew.Text = "Nuevo"
    $btnNew.Location = New-Object Drawing.Point(320,120)
    $btnNew.Size = New-Object Drawing.Size(120,35)

    $btnNew.Add_Click({

        $txtUser.Clear()

        $list.ClearSelected()

    })

    $formUsers.Controls.Add($btnNew)

    # ==================================
    # GUARDAR
    # ==================================

    $btnSave = New-Object System.Windows.Forms.Button

    $btnSave.Text = "Guardar"
    $btnSave.Location = New-Object Drawing.Point(450,120)
    $btnSave.Size = New-Object Drawing.Size(120,35)

    $btnSave.Add_Click({

        $newUser =
            $txtUser.Text.Trim()

        if(
            [string]::IsNullOrWhiteSpace(
                $newUser
            )
        ){
            Show-Error "Usuario obligatorio."
            return
        }

        try{

            if($null -eq $list.SelectedItem){

                Add-LauncherUser $newUser

            }
            else{

                $oldUser =
                    $list.SelectedItem.ToString()

                Update-LauncherUser `
                    $oldUser `
                    $newUser

            }

            Refresh-Users
            Refresh-MainCombo

            Show-Info "Usuario guardado."

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formUsers.Controls.Add($btnSave)

    # ==================================
    # ELIMINAR
    # ==================================

    $btnDelete = New-Object System.Windows.Forms.Button

    $btnDelete.Text = "Eliminar"
    $btnDelete.Location = New-Object Drawing.Point(320,170)
    $btnDelete.Size = New-Object Drawing.Size(250,35)

    $btnDelete.Add_Click({

        if($null -eq $list.SelectedItem){
            return
        }

        try{

            Remove-LauncherUser `
                $list.SelectedItem.ToString()

            Refresh-Users
            Refresh-MainCombo

            $txtUser.Clear()

            Show-Info "Usuario eliminado."

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formUsers.Controls.Add($btnDelete)

    # ==================================
    # INFO
    # ==================================

    $lblInfo = New-Object System.Windows.Forms.Label

    $lblInfo.AutoSize = $true
    $lblInfo.Location = New-Object Drawing.Point(320,230)

    $lblInfo.Text =
        "El usuario predeterminado no puede" +
        [Environment]::NewLine +
        "editarse ni eliminarse."

    $formUsers.Controls.Add($lblInfo)
    
    # ==================================
    # CERRAR
    # ==================================

    $btnClose = New-Object System.Windows.Forms.Button

    $btnClose.Text = "Cerrar"
    $btnClose.Location = New-Object Drawing.Point(320,300)
    $btnClose.Size = New-Object Drawing.Size(250,40)

    $btnClose.Add_Click({

        $formUsers.Close()

    })

    $formUsers.Controls.Add($btnClose)

    # ==================================
    # SHOW
    # ==================================

    [void]$formUsers.ShowDialog()

}