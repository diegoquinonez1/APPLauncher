. (Join-Path $PSScriptRoot "TestSupport.ps1")

Describe "Sprint 6: exportación e importación de perfil" {

    BeforeEach {
        $script:testRoot = New-AONTestRoot
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        . (Join-Path $script:AONTestRepositoryRoot "Modules\UserManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\CredentialManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\ProfileTransfer.ps1")
        $script:passphrase = ConvertTo-SecureString "portable-profile-passphrase" -AsPlainText -Force
        Save-LauncherCredential `
            -Environment "DEV" `
            -User "test-user" `
            -Password "ProfileTransfer-Test-Secret"
    }

    AfterEach {
        $script:passphrase.Dispose()
        Remove-AONTestRoot $script:testRoot
    }

    It "Exporta la configuración a ZIP sin incluir credenciales en texto plano" {
        $destination = Join-Path $script:testRoot "test-user.profile.zip"
        Export-LauncherProfile -DestinationPath $destination -Passphrase $script:passphrase

        Test-Path -LiteralPath $destination | Should Be $true
        $archive = [IO.Compression.ZipFile]::OpenRead($destination)
        try{
            $entryNames = @($archive.Entries | ForEach-Object {$_.FullName})
            $entryNames -contains "profile.json" | Should Be $true
            $entryNames -contains "credentials.json.enc" | Should Be $true
            $archiveText = ""
            foreach($entry in $archive.Entries){
                $stream = $entry.Open()
                $reader = New-Object IO.StreamReader($stream)
                try{
                    $archiveText += $reader.ReadToEnd()
                }
                finally{
                    $reader.Dispose()
                    $stream.Dispose()
                }
            }
            $archiveText.Contains("ProfileTransfer-Test-Secret") | Should Be $false
        }
        finally{
            $archive.Dispose()
        }
    }

    It "Rechaza una frase de paso incorrecta sin modificar la configuración" {
        $destination = Join-Path $script:testRoot "test-user.profile.zip"
        Export-LauncherProfile -DestinationPath $destination -Passphrase $script:passphrase
        Save-JsonFile "users.json" ([PSCustomObject]@{defaultUser="target-user";users=@("target-user")})
        $before = [IO.File]::ReadAllText((Join-Path $Global:ConfigFolder "users.json"))
        $wrongPassphrase = ConvertTo-SecureString "incorrect-profile-passphrase" -AsPlainText -Force
        try{
            (Test-AONThrows {
                Import-LauncherProfile -SourcePath $destination -Passphrase $wrongPassphrase
            }) | Should Be $true
        }
        finally{
            $wrongPassphrase.Dispose()
        }

        [IO.File]::ReadAllText((Join-Path $Global:ConfigFolder "users.json")) | Should Be $before
        (Get-ChildItem -LiteralPath $Global:BackupFolder -Directory).Count | Should Be 0
    }

    It "Importa la configuración con backup y vuelve a cifrar credenciales con DPAPI" {
        $destination = Join-Path $script:testRoot "test-user.profile.zip"
        Export-LauncherProfile -DestinationPath $destination -Passphrase $script:passphrase
        Save-JsonFile "users.json" ([PSCustomObject]@{defaultUser="target-user";users=@("target-user")})

        $result = Import-LauncherProfile -SourcePath $destination -Passphrase $script:passphrase

        $result.BackupCreated | Should Be $true
        $result.ImportedFiles | Should Be 7
        (Get-Users).users[0] | Should Be "test-user"
        $localCredential = (Get-Credentials).credentials[0]
        $localCredential.password.Contains("ProfileTransfer-Test-Secret") | Should Be $false
        (Get-LauncherCredential "DEV" "test-user").Password | Should Be "ProfileTransfer-Test-Secret"
        (Get-ChildItem -LiteralPath $Global:BackupFolder -Directory).Count | Should Be 1
    }

    It "Rechaza archivos ZIP que contengan entradas no permitidas antes de importar" {
        $destination = Join-Path $script:testRoot "test-user.profile.zip"
        Export-LauncherProfile -DestinationPath $destination -Passphrase $script:passphrase
        $archive = [IO.Compression.ZipFile]::Open(
            $destination,
            [IO.Compression.ZipArchiveMode]::Update
        )
        try{
            $entry = $archive.CreateEntry("../Config/credentials.json")
            $writer = New-Object IO.StreamWriter($entry.Open())
            try{
                $writer.Write("{}");
            }
            finally{
                $writer.Dispose()
            }
        }
        finally{
            $archive.Dispose()
        }

        (Test-AONThrows {
            Import-LauncherProfile -SourcePath $destination -Passphrase $script:passphrase
        }) | Should Be $true
        (Get-ChildItem -LiteralPath $Global:BackupFolder -Directory).Count | Should Be 0
    }
}
