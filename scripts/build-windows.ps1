# Builds the CLI and the Windows app into build\windows. -Install copies it to
# %LOCALAPPDATA%\Programs\QuickTranslator, adds a Start menu shortcut and launches it.
param([switch]$Install)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root 'build\windows'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\QuickTranslator'

function Invoke-Checked([scriptblock]$command) {
    & $command
    if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
}

Push-Location (Join-Path $root 'cli')
try {
    Invoke-Checked { npm install --silent }
    Invoke-Checked { npm run --silent build }
} finally {
    Pop-Location
}

if (Test-Path $output) { Remove-Item -Recurse -Force $output }
Invoke-Checked { dotnet publish (Join-Path $root 'windows\QuickTranslator\QuickTranslator.csproj') -c Release -o $output --nologo -v quiet }

# The app runs the CLI from this repo with this Node, like the macOS Info.plist (QTNodePath / QTCLIPath).
# realpath resolves version-manager shims (fnm, nvm) whose per-shell links disappear.
$paths = [ordered]@{
    nodePath = (node -p "require('fs').realpathSync(process.execPath)")
    cliPath  = Join-Path $root 'cli\dist\cli.js'
}
$paths | ConvertTo-Json | Set-Content -Encoding utf8NoBOM (Join-Path $output 'paths.json')
Write-Host "Built: $output"

if ($Install) {
    Get-Process QuickTranslator -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    if (Test-Path $installDir) { Remove-Item -Recurse -Force $installDir }
    Copy-Item -Recurse $output $installDir

    $exe = Join-Path $installDir 'QuickTranslator.exe'
    $shortcutPath = Join-Path ([Environment]::GetFolderPath('Programs')) 'Quick Translator.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exe
    $shortcut.WorkingDirectory = $installDir
    $shortcut.Save()

    Start-Process $exe
    Write-Host "Installed: $installDir"
}
