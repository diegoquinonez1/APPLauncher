function Show-UsersForm {

    param(
        [System.Windows.Forms.ComboBox]$MainUserCombo
    )

    $formUsers = New-Object System.Windows.Forms.Form

    $formUsers.Text = "Administración de Usuarios"
    $formUsers.Width = 500
    $formUsers.Height = 400
    $formUsers.StartPosition = "CenterParent"

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object Drawing.Point(20,20)
    $list.Size = New-Object Drawing.Size(300,250)

    $users = Get-Users

    foreach($user in $users.users){

        [void]$list.Items.Add($user)

    }

    $formUsers.Controls.Add($list)

    # AGREGAR

    $btnAdd = New-Object System.Windows.Forms.Button
    $btnAdd.Text = "Agregar"
    $btnAdd.Location = New-Object Drawing.Point(340,20)

    $btnAdd.Add_Click({

        $newUser =
        [Microsoft.VisualBasic.Interaction]::InputBox(
            "Nuevo usuario",
            "Agregar usuario"
        )

        if([string]::IsNullOrWhiteSpace($newUser)){
            return
        }

        try{

            Add-LauncherUser $newUser

            [void]$list.Items.Add($newUser)

            [void]$MainUserCombo.Items.Add($newUser)

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formUsers.Controls.Add($btnAdd)

    # ELIMINAR

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "Eliminar"
    $btnDelete.Location = New-Object Drawing.Point(340,60)

    $btnDelete.Add_Click({

        if(!$list.SelectedItem){
            return
        }

        try{

            Remove-LauncherUser `
                $list.SelectedItem.ToString()

            $list.Items.Remove(
                $list.SelectedItem
            )

            $MainUserCombo.Items.Clear()
            
            (Get-Users).users |
            ForEach-Object {
                
                [void]$MainUserCombo.Items.Add($_)
                
            }

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formUsers.Controls.Add($btnDelete)

    # EDITAR

    $btnEdit = New-Object System.Windows.Forms.Button
    $btnEdit.Text = "Editar"
    $btnEdit.Location = New-Object Drawing.Point(340,100)

    $btnEdit.Add_Click({

        if(!$list.SelectedItem){
            return
        }

        $oldUser =
            $list.SelectedItem.ToString()

        $newUser =
        [Microsoft.VisualBasic.Interaction]::InputBox(
            "Nuevo valor",
            "Editar Usuario",
            $oldUser
        )

        if([string]::IsNullOrWhiteSpace($newUser)){
            return
        }

        try{

            Update-LauncherUser `
                $oldUser `
                $newUser

            $index =
                $list.SelectedIndex

            $list.Items.RemoveAt($index)

            $list.Items.Insert(
                $index,
                $newUser
            )

            $MainUserCombo.Items.Clear()

            (Get-Users).users |
            ForEach-Object {

            [void]$MainUserCombo.Items.Add($_)

            }

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formUsers.Controls.Add($btnEdit)

    [void]$formUsers.ShowDialog()
}