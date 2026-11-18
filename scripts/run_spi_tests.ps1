param([switch]$Clean, [switch]$Synthesis, [switch]$FullRegression)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'activate_tools.ps1')
Push-Location $projectRoot
try {
    if ($Clean) {
        & make clean
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    if ($FullRegression) { & make -j4 regression }
    else { & make -j4 test-spi test-spi-cdc }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($Synthesis) {
        & make synth-spi
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
} finally { Pop-Location }
exit 0
