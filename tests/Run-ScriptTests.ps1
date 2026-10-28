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
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('snake script fixture %TEMP% ! ' + [guid]::NewGuid())
$previousGodot = $env:GODOT_BIN
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $fixture = Join-Path $temporary 'godot fixture.ps1'
    $command = (Get-Command powershell.exe -CommandType Application).Source
    @'
param($Mode, $Value)
switch ($Mode) {
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
    Write-Host 'PowerShell script contracts passed.'
} finally {
    $env:GODOT_BIN = $previousGodot
    Remove-Item -LiteralPath $fixture -Force -ErrorAction SilentlyContinue
    [IO.Directory]::Delete($temporary)
}
