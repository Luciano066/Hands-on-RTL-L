param([switch]$Clean)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'activate_tools.ps1')
if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
    throw 'Dependencia ausente: make. Consulte README.md.'
}
Push-Location $projectRoot
try {
    if ($Clean) {
        & make clean
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & make test-aes-dp
    $testExit = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $testExit
