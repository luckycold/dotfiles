#Requires -Version 5.1
<#
.SYNOPSIS
Installs Notion CLI, signs in, and opens the newest daily note in the browser.
.DESCRIPTION
First run saves the journal settings and creates a desktop shortcut. Later runs
query the latest entry dated today or earlier. Notion CLI manages credentials.
Use -Setup to choose a different journal or -PrintUrl to skip opening the browser.
#>
[CmdletBinding()]
param(
    [string]$DatabaseUrl = '',
    [string]$DataSourceId = '',
    [string]$DateProperty = 'Date',
    [switch]$Setup,
    [switch]$PrintUrl
)

$ErrorActionPreference = 'Stop'

function Ensure-NotionCli {
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
        throw 'Run this script on Windows 10 or 11.'
    }
    $command = Get-Command ntn.exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $command) {
        $architecture = $env:PROCESSOR_ARCHITEW6432
        if (-not $architecture) { $architecture = $env:PROCESSOR_ARCHITECTURE }
        if ($architecture -ne 'AMD64') { throw 'Notion CLI currently requires Windows x64.' }
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'
            throw 'Install Microsoft App Installer from the Store window, then run this script again.'
        }
        Write-Host 'Installing the official Notion CLI...'
        $ErrorActionPreference = 'Continue'
        & winget.exe install --id Notion.ntn --exact --source winget --scope user --silent `
            --accept-package-agreements --accept-source-agreements --disable-interactivity
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -ne 0) { throw "Notion CLI installation failed (exit $LASTEXITCODE)." }
        # WinGet updates PATH for new terminals; refresh this process too.
        $env:Path = @(
            [Environment]::GetEnvironmentVariable('Path', 'Machine')
            [Environment]::GetEnvironmentVariable('Path', 'User')
            (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links')
            $env:Path
        ) -join ';'
        $command = Get-Command ntn.exe -CommandType Application -ErrorAction SilentlyContinue
    }
    if (-not $command) { throw 'Notion CLI was not found. Close PowerShell and run the script again.' }
    return $command.Source
}

function Invoke-NotionApi {
    param([string]$Path, $Body = $null)
    $requestFile = $null
    try {
        $arguments = @('api', $Path)
        if ($null -ne $Body) {
            # A file avoids JSON quoting problems in Windows PowerShell 5.1.
            $requestFile = [IO.Path]::GetTempFileName()
            [IO.File]::WriteAllText($requestFile, ($Body | ConvertTo-Json -Depth 10 -Compress),
                (New-Object Text.UTF8Encoding $false))
            $arguments += @('--data', "@$requestFile")
        }
        $ErrorActionPreference = 'Continue'
        $output = & $script:NotionCommand @arguments 2>&1
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($exitCode -ne 0) { throw "Notion request failed: $($output -join [Environment]::NewLine)" }
        return (($output -join [Environment]::NewLine) | ConvertFrom-Json)
    }
    finally {
        if ($requestFile) { Remove-Item -LiteralPath $requestFile -Force -ErrorAction SilentlyContinue }
    }
}

function Connect-Notion {
    $ErrorActionPreference = 'Continue'
    $output = & $script:NotionCommand login --no-browser 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($exitCode -ne 0) { throw "Notion login failed: $($output -join [Environment]::NewLine)" }
    $text = $output -join [Environment]::NewLine
    Write-Host $text
    $url = [regex]::Match($text,
        'https://app\.notion\.com/workers/cli-login\?verificationCode=[A-Za-z0-9-]+').Value
    if (-not $url) { throw 'Notion did not return a login link. Run ntn login and try again.' }
    Write-Host 'In the browser, sign in and verify the code shown above before approving.'
    Start-Process -FilePath $url
    $ErrorActionPreference = 'Continue'
    & $script:NotionCommand login poll
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) {
        throw 'Login was not completed. Try again; Notion CLI requires full workspace membership.'
    }
}

function Get-NotionDatabaseId {
    param([string]$Value)
    $valueToParse = $Value.Trim()
    if ($valueToParse -match '^https?://') {
        $uri = [uri]$valueToParse
        if ($uri.Scheme -ne 'https' -or $uri.Host -notmatch '(^|\.)(notion\.so|notion\.site|notion\.com)$') {
            throw 'Paste an HTTPS Notion database link.'
        }
        # Ignore the view ID in ?v=; the database ID is in the URL path.
        $valueToParse = $uri.AbsolutePath.TrimEnd('/')
    }
    $match = [regex]::Match($valueToParse,
        '(?i)([0-9a-f]{32}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$')
    if (-not $match.Success) { throw 'Could not find a database ID. Copy the journal database link, not an entry link.' }
    return ([guid]$match.Value).ToString()
}

function Invoke-LatestNotionNote {
    $script:NotionCommand = Ensure-NotionCli
    try { $null = Invoke-NotionApi 'v1/users/me' }
    catch {
        Write-Host 'Notion access needs attention. Starting browser login...'
        Connect-Notion
        $null = Invoke-NotionApi 'v1/users/me'
    }

    $installDirectory = Join-Path $env:LOCALAPPDATA 'NotionDailyNote'
    $configFile = Join-Path $installDirectory 'journal.json'
    if ($Setup -or -not (Test-Path -LiteralPath $configFile)) {
        if (-not $DataSourceId) {
            if (-not $DatabaseUrl) { $DatabaseUrl = Read-Host 'Paste the journal DATABASE link' }
            $databaseId = Get-NotionDatabaseId $DatabaseUrl
            $database = Invoke-NotionApi "v1/databases/$databaseId"
            $sources = @($database.data_sources)
            if ($sources.Count -eq 0) { throw 'This database has no data sources.' }
            $sourceIndex = 0
            if ($sources.Count -gt 1) {
                for ($i = 0; $i -lt $sources.Count; $i++) { Write-Host "$($i + 1). $($sources[$i].name)" }
                $choice = 0
                if (-not [int]::TryParse((Read-Host 'Choose the journal number'), [ref]$choice) -or
                    $choice -lt 1 -or $choice -gt $sources.Count) { throw 'Invalid journal number.' }
                $sourceIndex = $choice - 1
            }
            $DataSourceId = [string]$sources[$sourceIndex].id
        }
        $DataSourceId = ([guid]$DataSourceId).ToString()
        $source = Invoke-NotionApi "v1/data_sources/$DataSourceId"
        $dateField = $source.properties.PSObject.Properties[$DateProperty]
        if (-not $dateField -or $dateField.Value.type -ne 'date') {
            throw "The journal must have a date property named '$DateProperty'. Use -DateProperty to change it."
        }
        $config = @{ DataSourceId = $DataSourceId; DateProperty = $DateProperty }
        $null = New-Item -ItemType Directory -Path $installDirectory -Force
        $config | ConvertTo-Json | Set-Content -LiteralPath $configFile -Encoding UTF8
    }
    else { $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json }

    $sourceId = ([guid]$config.DataSourceId).ToString()
    $query = @{
        filter = @{ property = $config.DateProperty; date = @{ on_or_before = (Get-Date -Format 'yyyy-MM-dd') } }
        sorts = @(@{ property = $config.DateProperty; direction = 'descending' })
        page_size = 1
    }
    $result = Invoke-NotionApi "v1/data_sources/$sourceId/query" $query
    $notes = @($result.results)
    if ($notes.Count -eq 0 -or -not $notes[0].id) { throw 'No journal entry dated today or earlier was found.' }
    $pageId = ([guid]$notes[0].id).ToString('N')
    $noteUrl = "https://www.notion.so/$pageId"
    if ($PrintUrl) { Write-Output $noteUrl; return }

    # Keep a stable copy so the shortcut survives moving the downloaded script.
    $installedScript = Join-Path $installDirectory 'Open-LatestNotionNote.ps1'
    if ([IO.Path]::GetFullPath($PSCommandPath) -ne [IO.Path]::GetFullPath($installedScript)) {
        Copy-Item -LiteralPath $PSCommandPath -Destination $installedScript -Force
    }
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ($desktop) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut((Join-Path $desktop 'Latest Notion Note.lnk'))
        $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $installedScript + '"'
        $shortcut.Description = 'Open the newest Notion daily note in your browser'
        $shortcut.Save()
    }
    Write-Host 'Opening the latest note. Next time, use Latest Notion Note on the desktop.'
    Start-Process -FilePath $noteUrl
}

# Dot-sourcing exposes the functions for verification without running setup.
if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-LatestNotionNote }
    catch { Write-Error $_ -ErrorAction Continue; exit 1 }
}
