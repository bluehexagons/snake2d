<# Native Windows tooling; no account configuration or Basaltwater dependency. #>
function Resolve-GodotCommand {
    $candidates = if ($env:GODOT_BIN) { @($env:GODOT_BIN) } else {
        @($env:GODOT, $env:GODOT4, $env:BASALTWATER_GODOT_EXE, 'godot', 'godot4')
    }
    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $command = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command -and [IO.Path]::GetExtension($command.Source) -eq '.exe') { return $command.Source }
    }
    throw 'Godot was not found. Install the documented engine version and set GODOT_BIN to its console executable.'
}

function Invoke-GodotCommand([string]$Command, [string[]]$Arguments, [string]$ExpectedMarker = '',
                             [ValidateRange(1, 3600)][int]$TimeoutSeconds = 120) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Command
    # Quote for the native Windows argv parser, without a cmd.exe boundary.
    $start.Arguments = (@($Arguments | ForEach-Object {
        '"' + [regex]::Replace([regex]::Replace($_, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
    }) -join ' ')
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.Encoding]::UTF8
    $start.StandardErrorEncoding = [Text.Encoding]::UTF8
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw 'Could not start Godot.' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        # GUI exports do not reliably set LASTEXITCODE or wait when invoked
        # with PowerShell's & operator. Own and wait for this process explicitly.
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            & taskkill.exe /PID $process.Id /T /F | Out-Null
            if ($LASTEXITCODE -ne 0 -or -not $process.WaitForExit(5000)) {
                throw 'Godot timed out and process-tree cleanup could not be confirmed.'
            }
        }
        if (-not $stdout.Wait(5000) -or -not $stderr.Wait(5000)) { throw 'Godot output streams did not close.' }
        $output = $stdout.Result + $stderr.Result
        if ($output) { Write-Host $output.TrimEnd() }
        if ($timedOut) { throw "Godot timed out after $TimeoutSeconds seconds." }
        if ($process.ExitCode -ne 0) { throw "Godot failed (exit code $($process.ExitCode))." }
        if ($output -match 'SCRIPT ERROR:|Parse Error:|Compile Error:|(?m)(?:^|\s)ERROR:') {
            throw 'Godot reported an error.'
        }
        if ($ExpectedMarker -and $ExpectedMarker -notin @($output -split '\r?\n')) {
            throw "Godot exited before reporting: $ExpectedMarker"
        }
    } finally { $process.Dispose() }
}
