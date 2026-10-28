. (Join-Path $PSScriptRoot "TestSupport.ps1")

Describe "Windows Forms: smoke tests de pantallas por funcionalidad" {

    BeforeEach {
        $script:testRoot = New-APPLauncherTestRoot
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\UserManager.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\FavoriteManager.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\QuickLinks.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\ProfileManager.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\ProjectsForm.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\UsersForm.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\FavoriteForm.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\QuickLinksForm.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\CredentialManager.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\ProfileTransfer.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\CredentialForm.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\LogManager.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\UiHelpers.ps1")
        $Global:LogFile = Join-Path $Global:LogFolder "launcher.log"
    }

    AfterEach {
        if($Global:APPLauncherTestPassphrase){
            $Global:APPLauncherTestPassphrase.Dispose()
            $Global:APPLauncherTestPassphrase = $null
        }
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
        Remove-APPLauncherTestRoot $script:testRoot
    }

    It "La pantalla de usuarios abre con lista, entrada, comandos e información de usuario predeterminado" {
        $mainUserCombo = New-Object System.Windows.Forms.ComboBox
        $Global:APPLauncherTestFormSnapshot = $null
        Invoke-AppLauncherWinFormsDialog `
            -Title "Administración de Usuarios" `
            -ShowForm { Show-UsersForm $mainUserCombo } `
            -OnShown {
                param($form)
                $controls = @([APPLauncherTestControlWalker]::GetDescendants($form))
                $Global:APPLauncherTestFormSnapshot = [PSCustomObject]@{
                    ControlCount = $controls.Count
                    HasUserList = @($controls | Where-Object {$_ -is [System.Windows.Forms.ListBox]}).Count -gt 0
                    HasSaveButton = @($controls | Where-Object {$_.Text -eq "Guardar"}).Count -gt 0
                    HasDefaultUserInfo = @($controls | Where-Object {$_.Text -like "*usuario predeterminado*"}).Count -gt 0
                }
            } | Out-Null

        $Global:APPLauncherTestFormSnapshot.HasUserList | Should Be $true
        $Global:APPLauncherTestFormSnapshot.HasSaveButton | Should Be $true
        $Global:APPLauncherTestFormSnapshot.HasDefaultUserInfo | Should Be $true
    }

    It "La pantalla de favoritos muestra selección de usuario, entorno y aplicación" {
        $Global:APPLauncherTestFormSnapshot = $null
        Invoke-AppLauncherWinFormsDialog `
            -Title "Favoritos" `
            -ShowForm { Show-FavoriteForm } `
            -OnShown {
                param($form)
                $controls = @([APPLauncherTestControlWalker]::GetDescendants($form))
                $Global:APPLauncherTestFormSnapshot = [PSCustomObject]@{
                    ComboCount = @($controls | Where-Object {$_ -is [System.Windows.Forms.ComboBox]}).Count
                    HasLaunchButton = @($controls | Where-Object {$_.Text -eq "Ejecutar"}).Count -gt 0
                    HasSaveButton = @($controls | Where-Object {$_.Text -eq "Guardar"}).Count -gt 0
                }
            } | Out-Null

        $Global:APPLauncherTestFormSnapshot.ComboCount | Should Be 3
        $Global:APPLauncherTestFormSnapshot.HasLaunchButton | Should Be $true
        $Global:APPLauncherTestFormSnapshot.HasSaveButton | Should Be $true
    }

    It "La pantalla de proyectos presenta acciones configurables y lista dinámica" {
        $Global:APPLauncherTestFormSnapshot = $null
        Invoke-AppLauncherWinFormsDialog `
            -Title "Administración de Proyectos" `
            -ShowForm { Show-ProjectsForm } `
            -OnShown {
                param($form)
                $controls = @([APPLauncherTestControlWalker]::GetDescendants($form))
                $Global:APPLauncherTestFormSnapshot = [PSCustomObject]@{
                    HasProjectList = @($controls | Where-Object {$_ -is [System.Windows.Forms.ListBox]}).Count -gt 0
                    StartupApps = @($controls | Where-Object {$_ -is [System.Windows.Forms.CheckBox]}).Count
                    HasSaveButton = @($controls | Where-Object {$_.Text -eq "Guardar"}).Count -gt 0
                    HasDeleteButton = @($controls | Where-Object {$_.Text -eq "Eliminar"}).Count -gt 0
                }
            } | Out-Null

        $Global:APPLauncherTestFormSnapshot.HasProjectList | Should Be $true
        $Global:APPLauncherTestFormSnapshot.StartupApps | Should Be 4
        $Global:APPLauncherTestFormSnapshot.HasSaveButton | Should Be $true
        $Global:APPLauncherTestFormSnapshot.HasDeleteButton | Should Be $true
    }

    It "La pantalla de accesos web conserva desplazamiento y comandos de gestión" {
        $Global:APPLauncherTestFormSnapshot = $null
        Invoke-AppLauncherWinFormsDialog `
            -Title "Administración de Accesos Web" `
            -ShowForm { Show-QuickLinksForm } `
            -OnShown {
                param($form)
                $controls = @([APPLauncherTestControlWalker]::GetDescendants($form))
                $Global:APPLauncherTestFormSnapshot = [PSCustomObject]@{
                    AutoScroll = $form.AutoScroll
                    HasList = @($controls | Where-Object {$_ -is [System.Windows.Forms.ListBox]}).Count -gt 0
                    HasSaveButton = @($controls | Where-Object {$_.Text -eq "Guardar"}).Count -gt 0
                    HasDeleteButton = @($controls | Where-Object {$_.Text -eq "Eliminar"}).Count -gt 0
                }
            } | Out-Null

        $Global:APPLauncherTestFormSnapshot.AutoScroll | Should Be $true
        $Global:APPLauncherTestFormSnapshot.HasList | Should Be $true
        $Global:APPLauncherTestFormSnapshot.HasSaveButton | Should Be $true
        $Global:APPLauncherTestFormSnapshot.HasDeleteButton | Should Be $true
    }

    It "La pantalla de credenciales tiene campos protegidos y acciones esperadas" {
        $Global:APPLauncherTestFormSnapshot = $null
        Invoke-AppLauncherWinFormsDialog `
            -Title "Administración de Credenciales" `
            -ShowForm { Show-CredentialForm -Users @("test-user") -Owner $null } `
            -OnShown {
                param($form)
                $controls = @([APPLauncherTestControlWalker]::GetDescendants($form))
                $passwordBox = @($controls | Where-Object {$_ -is [System.Windows.Forms.TextBox]})[0]
                $Global:APPLauncherTestFormSnapshot = [PSCustomObject]@{
                    PasswordMasked = $passwordBox.UseSystemPasswordChar
                    HasVerify = @($controls | Where-Object {$_.Text -eq "Verificar"}).Count -gt 0
                    HasCopy = @($controls | Where-Object {$_.Text -eq "Copiar Contraseña"}).Count -gt 0
                    HasDelete = @($controls | Where-Object {$_.Text -eq "Eliminar"}).Count -gt 0
                }
            } | Out-Null

        $Global:APPLauncherTestFormSnapshot.PasswordMasked | Should Be $true
        $Global:APPLauncherTestFormSnapshot.HasVerify | Should Be $true
        $Global:APPLauncherTestFormSnapshot.HasCopy | Should Be $true
        $Global:APPLauncherTestFormSnapshot.HasDelete | Should Be $true
    }

    It "La passphrase introducida en el diálogo se devuelve al flujo de exportación" {
        $Global:APPLauncherTestPassphrase = $null

        Invoke-AppLauncherWinFormsDialog `
            -Title "Prueba automatizada de passphrase" `
            -ShowForm {
                $Global:APPLauncherTestPassphrase = Show-LauncherProfilePassphraseDialog `
                    -Title "Prueba automatizada de passphrase" `
                    -ConfirmPassphrase $true `
                    -Owner $null
            } `
            -OnShown {
                param($form)
                $controls = @([APPLauncherTestControlWalker]::GetDescendants($form))
                $passwordFields = @($controls | Where-Object {$_ -is [System.Windows.Forms.TextBox]})
                $acceptButton = @($controls | Where-Object {$_.Text -eq "Aceptar"})[0]
                $passwordFields[0].Text = "test-profile-passphrase-2026"
                $passwordFields[1].Text = "test-profile-passphrase-2026"
                $acceptButton.PerformClick()
            } | Out-Null

        $null -ne $Global:APPLauncherTestPassphrase | Should Be $true
        $Global:APPLauncherTestPassphrase.Length | Should BeGreaterThan 12

        $profilePath = Join-Path $script:testRoot "ui-export.profile.zip"
        Export-LauncherProfile `
            -DestinationPath $profilePath `
            -Passphrase $Global:APPLauncherTestPassphrase

        Test-Path -LiteralPath $profilePath | Should Be $true
    }
}
