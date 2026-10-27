. (Join-Path $PSScriptRoot "TestSupport.ps1")

Describe "Sprint 4: accesos web" {

    BeforeEach {
        $script:testRoot = New-APPLauncherTestRoot
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\QuickLinks.ps1")
    }

    AfterEach {
        Remove-APPLauncherTestRoot $script:testRoot
    }

    It "Normaliza nombre y URL absoluta HTTP/HTTPS" {
        $link = ConvertTo-QuickLink ([PSCustomObject]@{
            name = "  Azure DevOps  "
            url = " https://example.com/team "
        })

        $link.name | Should Be "Azure DevOps"
        $link.url | Should Be "https://example.com/team"
    }

    It "Rechaza enlaces sin nombre, URL relativa, esquema no permitido o credenciales" {
        (Test-APPLauncherThrows { ConvertTo-QuickLink ([PSCustomObject]@{name=" ";url="https://example.com"}) }) | Should Be $true
        (Test-APPLauncherThrows { ConvertTo-QuickLink ([PSCustomObject]@{name="Relative";url="/path"}) }) | Should Be $true
        (Test-APPLauncherThrows { ConvertTo-QuickLink ([PSCustomObject]@{name="Script";url="javascript:alert(1)"}) }) | Should Be $true
        (Test-APPLauncherThrows { ConvertTo-QuickLink ([PSCustomObject]@{name="Credentials";url="https://user:secret@example.com"}) }) | Should Be $true
    }

    It "Guarda enlaces únicos y conserva los existentes si una entrada nueva no es válida" {
        Save-QuickLinks -Links @(
            [PSCustomObject]@{name="Jira";url="https://example.com/jira"},
            [PSCustomObject]@{name="Teams";url="https://example.com/teams"}
        )

        (Test-APPLauncherThrows {
            Save-QuickLinks -Links @(
                [PSCustomObject]@{name="Confluence";url="https://example.com/wiki"},
                [PSCustomObject]@{name="Bad";url="file:///etc/passwd"}
            )
        }) | Should Be $true

        $links = @(Get-QuickLinks)
        $links.Count | Should Be 2
        $links[0].name | Should Be "Jira"
    }

    It "Rechaza nombres duplicados y no guarda la colección duplicada" {
        $duplicateLinks = @(
            [PSCustomObject]@{name="Azure DevOps";url="https://example.com/a"},
            [PSCustomObject]@{name="Azure DevOps";url="https://example.com/b"}
        )

        (Test-APPLauncherThrows { Save-QuickLinks -Links $duplicateLinks }) | Should Be $true
        @((Get-QuickLinks)).Count | Should Be 0
    }

    It "Abre el destino validado en el navegador predeterminado" {
        Mock Start-Process {}

        Open-QuickLink ([PSCustomObject]@{name="Jira";url="https://example.com/jira"})

        Assert-MockCalled Start-Process -Times 1 -Scope It -ParameterFilter {
            $FilePath -eq "https://example.com/jira"
        }
    }
}
