<# Export with the project's presets, independent of Bash and Basaltwater. #>
[CmdletBinding()]
param([ValidateSet('windows', 'web', 'linux', 'all')][string]$Platform = 'windows',
      [ValidateRange(1, 3600)][int]$TimeoutSeconds = 120)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'scripts\Godot.Common.ps1')
$godot = Resolve-GodotCommand
$exports = [ordered]@{
    windows = @('Windows Desktop', 'out\win64\snake.exe')
    web = @('Web', 'out\html\index.html')
    linux = @('Linux', 'out\linux64\snake.x86_64')
}
$selected = if ($Platform -eq 'all') { @($exports.Keys) } else { @($Platform) }
foreach ($name in $selected) {
    $preset, $relative = $exports[$name]
    $output = Join-Path $PSScriptRoot $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
    Invoke-GodotCommand $godot @('--headless', '--path', $PSScriptRoot, '--export-release', $preset, $output) -TimeoutSeconds $TimeoutSeconds
    if (-not (Test-Path -LiteralPath $output -PathType Leaf) -or (Get-Item -LiteralPath $output).Length -eq 0) {
        throw "Expected export output was not created: $output"
    }
}
