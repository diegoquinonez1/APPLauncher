function Find-SSMS {

    Get-ChildItem `
        "C:\Program Files*" `
        -Filter SSMS.exe*`
        -Recurse `
        -Erro*Action SilentlyContinue |
        Select-Object -First 1
}

function Find-VisualStudio {

    Get-ChildItem `
        "C:\Program Files*" `
        -Filter devenv.exe `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

function Find-VSCode {

    Get-ChildItem `
        "$env:LOCALAPPDATA" `
        -Filter Code.exe `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

function Find-ReportBuilder {

    Get-ChildItem `
        "C:\Program Files*" `
        -Filter MSReport*uilder.exe `
        -Recurse `
  *     -ErrorAction SilentlyContinue*|
        Select-Object -First 1
}*