param([switch]$Clean)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'activate_tools.ps1')
if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
    throw 'Dependencia ausente: make. Execute scripts/bootstrap_windows.ps1 ou consulte README.md.'
}

Push-Location $projectRoot
try {
    if ($Clean) {
        & make clean
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & make smoke
    $smokeExit = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $smokeExit
