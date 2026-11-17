<# Export with the project's presets, independent of Bash and Basaltwater. #>
[CmdletBinding()]
param([ValidateSet('windows', 'web', 'linux', 'all')][string]$Platform = 'windows',
      [ValidateRange(1, 3600)][int]$TimeoutSeconds = 120)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'scripts\Godot.Common.ps1')
$godot = Resolve-GodotCommand
$exports = [ordered]@{
    windows = @('Windows Desktop', 'out\win64\snake.exe', 'snake.pck')
    web = @('Web', 'out\html\index.html', 'index.js', 'index.wasm', 'index.pck',
        'index.audio.worklet.js', 'index.audio.position.worklet.js')
    linux = @('Linux', 'out\linux64\snake.x86_64', 'snake.pck')
}
$selected = if ($Platform -eq 'all') { @($exports.Keys) } else { @($Platform) }
foreach ($name in $selected) {
    $preset, $relative, $companions = $exports[$name]
    $output = Join-Path $PSScriptRoot $relative
    $outputDirectory = Split-Path -Parent $output
    # An earlier build must not mask a missing file in this invocation.
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    $staging = Join-Path $outputDirectory ('.export.' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $staging | Out-Null
    try {
        New-Item -ItemType File -Path (Join-Path $staging '.gdignore') | Out-Null
        $filename = Split-Path -Leaf $output
        $stagedOutput = Join-Path $staging $filename
        Invoke-GodotCommand $godot @('--headless', '--path', $PSScriptRoot, '--export-release', $preset, $stagedOutput) -TimeoutSeconds $TimeoutSeconds
        foreach ($required in (@($filename) + $companions)) {
            $file = Join-Path $staging $required
            if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file).Length -eq 0) {
                throw "Expected export output was not created: $required"
            }
        }
        foreach ($file in Get-ChildItem -LiteralPath $staging -File) {
            if ($file.Name -ne '.gdignore') {
                Copy-Item -LiteralPath $file.FullName -Destination $outputDirectory -Force
            }
        }
    } finally {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}
