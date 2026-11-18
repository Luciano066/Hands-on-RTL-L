param([switch]$Synthesis)
# Reproducible logged regression. No downloads or global environment changes.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'activate_tools.ps1')
function Invoke-LoggedMake([string[]]$MakeArguments, [string]$LogPath) {
    & make @MakeArguments 2>&1 | ForEach-Object { "$_" } | Set-Content -Encoding UTF8 $LogPath
    $toolExit = $LASTEXITCODE
    if ($toolExit -ne 0) { Get-Content $LogPath -Tail 60; exit $toolExit }
    Select-String -Path $LogPath -Pattern 'TEST PASS|GNU Make |Verilator 5|Icarus Verilog version|[Ww]arning|ERROR:' | ForEach-Object { $_.Line }
}
Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Force build | Out-Null
    # Native tools write version information on stderr even on success.
    $ErrorActionPreference = 'Continue'
    Invoke-LoggedMake @('versions') 'build/w05_versions.log'
    Invoke-LoggedMake @('clean') 'build/w05_clean.log'
    Invoke-LoggedMake @('-j4','regression') 'build/w05_regression.log'
    if ($Synthesis) {
        & yosys -V | Add-Content build/w05_versions.log
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Invoke-LoggedMake @('synth-spi','synth-aes') 'build/w05_synthesis.log'
        Write-Output 'Generic synthesis finished: SPI, CDC, AES dp/key/core. See build/*_synth.log.'
    }
} finally { Pop-Location }
exit 0
