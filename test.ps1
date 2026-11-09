<# Windows PowerShell 5.1 source tests and native export startup. #>
[CmdletBinding()]
param([ValidateSet('source', 'windows-export', 'all')][string]$Mode = 'source',
      [ValidateRange(1, 3600)][int]$TimeoutSeconds = 120)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'scripts\Godot.Common.ps1')

if ($Mode -in @('source', 'all')) {
    $godot = Resolve-GodotCommand
    Invoke-GodotCommand $godot @('--headless', '--path', $PSScriptRoot, '--import', '--quit') -TimeoutSeconds $TimeoutSeconds
    foreach ($suite in Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tests\source-suites.txt')) {
        if (-not $suite) { continue }
        $parts = $suite.Split('|')
        if ($parts.Count -ne 2 -or $parts[0] -notmatch '\A[a-z_]+_test\.gd\z' -or -not $parts[1]) {
            throw "Invalid source suite: $suite"
        }
        Invoke-GodotCommand $godot @('--headless', '--path', $PSScriptRoot, '--script', "res://tests/$($parts[0])") $parts[1] -TimeoutSeconds $TimeoutSeconds
    }
    Invoke-GodotCommand $godot @('--headless', '--path', $PSScriptRoot, '--scene', 'res://tests/smoke_test.tscn', '--quit-after', '300') 'Smoke test passed.' -TimeoutSeconds $TimeoutSeconds
}
if ($Mode -eq 'all') {
    & (Join-Path $PSScriptRoot 'build.ps1') windows -TimeoutSeconds $TimeoutSeconds
}
if ($Mode -in @('windows-export', 'all')) {
    $export = Join-Path $PSScriptRoot 'out\win64\snake.exe'
    if (-not (Test-Path -LiteralPath $export -PathType Leaf)) {
        throw 'Windows export not found. Run build.ps1 windows first.'
    }
    # An empty working directory prevents source files from masking bad packages.
    # APPDATA isolates Godot's user:// saves (including legacy migration) and logs.
    $smokeDirectory = Join-Path ([IO.Path]::GetTempPath()) ('snake export ' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $smokeDirectory | Out-Null
    Push-Location -LiteralPath $smokeDirectory
    try {
        Invoke-GodotCommand $export @('--headless', '--quit-after', '1') -TimeoutSeconds $TimeoutSeconds -Environment @{ APPDATA = $smokeDirectory }
    } finally {
        Pop-Location
        # Only this invocation's newly created directory is disposable.
        Remove-Item -LiteralPath $smokeDirectory -Recurse -Force
    }
}
