param([switch]$Clean, [switch]$Synthesis)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'activate_tools.ps1')
Push-Location $projectRoot
try {
    if ($Clean) {
        & make clean
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & make -j4 regression
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($Synthesis) {
        & make synth-aes
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
} finally {
    Pop-Location
}
exit 0
