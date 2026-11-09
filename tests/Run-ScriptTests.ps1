<# Offline failure-contract checks; no real engine or account changes. #>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '..\scripts\Godot.Common.ps1')
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
    try { & $Action } catch {
        if ($_.Exception.Message -match $Pattern) { return }
        throw
    }
    throw "Expected failure: $Pattern"
}
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('snake script fixture caf' + [char]0xe9 + ' %TEMP% ! ' + [guid]::NewGuid())
$previousGodot = $env:GODOT_BIN
$previousAppData = $env:APPDATA
$previousReport = $env:SNAKE_FIXTURE_REPORT
$previousMode = $env:SNAKE_FIXTURE_MODE
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $fixture = Join-Path $temporary 'godot fixture.ps1'
    $command = (Get-Command powershell.exe -CommandType Application).Source
    @'
param($Mode, $Value, $OutputPath)
switch ($Mode) {
    'compile' { Add-Type -TypeDefinition (Get-Content -LiteralPath $Value -Raw) -OutputAssembly $OutputPath -OutputType WindowsApplication }
    'fail' { exit 23 }
    'script-error' { Write-Output 'SCRIPT ERROR: fixture failure' }
    'marker' { Write-Output 'Suite passed.' }
    'warning' { [Console]::Error.WriteLine('harmless diagnostic') }
    'argument' { Write-Output ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))) }
    'hang' { Start-Sleep -Seconds 20 }
}
exit 0
'@ | Set-Content -LiteralPath $fixture -Encoding ASCII
    $baseArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $fixture)
    $env:GODOT_BIN = $command
    if ((Resolve-GodotCommand) -ne $command) { throw 'Explicit Godot path was not used' }
    Invoke-GodotCommand $command ($baseArguments + @('marker')) 'Suite passed.'
    Invoke-GodotCommand $command ($baseArguments + @('warning'))
    foreach ($value in @('C:\cache with spaces\', 'a"quoted"argument', 'literal %TEMP% !')) {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($value))
        Invoke-GodotCommand $command ($baseArguments + @('argument', $value)) $encoded
    }
    Assert-Throws { Invoke-GodotCommand $command ($baseArguments + @('fail')) } 'exit code 23'
    Assert-Throws { Invoke-GodotCommand $command ($baseArguments + @('script-error')) } 'reported an error'
    Assert-Throws { Invoke-GodotCommand $command ($baseArguments + @('early-exit')) 'Suite passed.' } 'before reporting'
    Assert-Throws { Invoke-GodotCommand $command ($baseArguments + @('hang')) -TimeoutSeconds 1 } 'timed out after 1 seconds'
    $env:GODOT_BIN = Join-Path $temporary 'missing.exe'
    Assert-Throws { Resolve-GodotCommand } 'Godot was not found'

    # Export-only checks must need neither an editor nor the player's profile.
    $project = Join-Path $temporary 'project'
    $exportDirectory = Join-Path $project 'out\win64'
    New-Item -ItemType Directory -Path $exportDirectory | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $project 'scripts') | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\test.ps1') -Destination $project
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\scripts\Godot.Common.ps1') -Destination (Join-Path $project 'scripts')
    Set-Content -LiteralPath (Join-Path $project 'project.godot') -Value 'source must not mask a bad package'
    $export = Join-Path $exportDirectory 'snake.exe'
    # Use the Windows PowerShell compiler even when this suite runs in PS 7.
    Invoke-GodotCommand $command ($baseArguments + @('compile', (Join-Path $PSScriptRoot 'fixtures\ExportFixture.cs'), $export))
    $env:APPDATA = Join-Path $temporary 'player data'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $sentinel = Join-Path $env:APPDATA 'settings.cfg'
    Set-Content -LiteralPath $sentinel -Value 'player settings'
    $env:SNAKE_FIXTURE_REPORT = Join-Path $temporary 'export report.txt'
    $runner = Join-Path $project 'test.ps1'
    Push-Location -LiteralPath $project
    try {
        $env:SNAKE_FIXTURE_MODE = 'pass'
        & $runner windows-export
        $smokeDirectory = Get-Content -LiteralPath $env:SNAKE_FIXTURE_REPORT -Raw
        if (Test-Path -LiteralPath $smokeDirectory) { throw 'Export smoke directory was not cleaned up' }
        if ((Get-Content -LiteralPath $sentinel) -ne 'player settings' -or $env:APPDATA -ne (Join-Path $temporary 'player data')) {
            throw 'Export smoke changed the player profile'
        }
        $env:SNAKE_FIXTURE_MODE = 'fail'
        Assert-Throws { & $runner windows-export } 'exit code 23'
        $env:SNAKE_FIXTURE_MODE = 'error'
        Assert-Throws { & $runner windows-export } 'reported an error'
        $env:SNAKE_FIXTURE_MODE = 'hang'
        Assert-Throws { & $runner windows-export -TimeoutSeconds 1 } 'timed out after 1 seconds'
        # Downloaded packages may be relocated outside the source/build tree.
        $relocated = Join-Path $temporary 'downloaded package'
        New-Item -ItemType Directory -Path $relocated | Out-Null
        $relocatedExport = Join-Path $relocated 'snake.exe'
        Move-Item -LiteralPath $export -Destination $relocatedExport
        $env:SNAKE_FIXTURE_MODE = 'pass'
        & $runner windows-export -WindowsExportPath '..\downloaded package\snake.exe'
        $env:SNAKE_FIXTURE_MODE = 'error'
        Assert-Throws { & $runner windows-export -WindowsExportPath $relocatedExport } 'reported an error'
        Assert-Throws { & $runner source -WindowsExportPath $relocatedExport } 'applies only to windows-export'
        Move-Item -LiteralPath $relocatedExport -Destination $export
        Remove-Item -LiteralPath $export -Force
        Assert-Throws { & $runner windows-export } 'Windows export not found'
    } finally { Pop-Location }
    Write-Host 'PowerShell script contracts passed.'
} finally {
    $env:GODOT_BIN = $previousGodot
    $env:APPDATA = $previousAppData
    $env:SNAKE_FIXTURE_REPORT = $previousReport
    $env:SNAKE_FIXTURE_MODE = $previousMode
    # $temporary is this run's fresh, absolute child of the system temp directory.
    Remove-Item -LiteralPath $temporary -Recurse -Force
}
