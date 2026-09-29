# Instalacao portatil e reproduzivel; nao altera PATH ou politicas globais.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsDir = Join-Path $projectRoot '.tools'
$suiteDir = Join-Path $toolsDir 'oss-cad-suite'
$archivePath = Join-Path $toolsDir 'oss-cad-suite-windows-x64-20260928.tgz'
$expectedHash = '71a0a16592db2070e6abf18f76463dcc6bc0c7d6c772f29a7fd925197a29e184'
$downloadUrl = 'https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-09-28/oss-cad-suite-windows-x64-20260928.tgz'

foreach ($dependency in @('curl.exe', 'tar.exe')) {
    if (-not (Get-Command $dependency -ErrorAction SilentlyContinue)) {
        throw "Dependencia ausente: $dependency. Consulte README.md."
    }
}

New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $archivePath)) {
    Write-Host 'Baixando OSS CAD Suite 2026-09-28 (aproximadamente 600 MB)...'
    & curl.exe --fail --location --retry 3 --output "$archivePath.part" $downloadUrl
    if ($LASTEXITCODE -ne 0) { throw "Download falhou: codigo $LASTEXITCODE" }
    Move-Item -LiteralPath "$archivePath.part" -Destination $archivePath
}
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw "SHA256 incorreto: $archivePath. Nao sera extraido ou executado."
}

if (-not (Test-Path -LiteralPath $suiteDir)) {
    Write-Host 'Extraindo toolchain local...'
    & tar.exe -xzf $archivePath -C $toolsDir
    if ($LASTEXITCODE -ne 0) { throw "Extracao falhou: codigo $LASTEXITCODE" }
}
if (-not (Test-Path -LiteralPath (Join-Path $suiteDir 'environment.ps1'))) {
    throw 'Instalacao incompleta em .tools/oss-cad-suite; inspecione antes de repetir.'
}

# O pacote Windows do OSS CAD Suite nao inclui GNU Make nem shell POSIX.
# O shell e as DLLs MSYS sao fornecidos pelo Git for Windows existente.
$makeArchive = Join-Path $toolsDir 'make-4.4.1-3-x86_64.pkg.tar.zst'
$makeHash = 'af0bdba17f06fe037f0194069adaa31a8fe45f1a11381501896aea1fae37bd5d'
$makeDir = Join-Path $toolsDir 'make'
if (-not (Test-Path -LiteralPath $makeArchive)) {
    & curl.exe --fail --location --retry 3 --output "$makeArchive.part" 'https://mirror.msys2.org/msys/x86_64/make-4.4.1-3-x86_64.pkg.tar.zst'
    if ($LASTEXITCODE -ne 0) { throw "Download do Make falhou: codigo $LASTEXITCODE" }
    Move-Item -LiteralPath "$makeArchive.part" -Destination $makeArchive
}
if ((Get-FileHash -LiteralPath $makeArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $makeHash) {
    throw 'SHA256 incorreto no pacote GNU Make; extracao cancelada.'
}
if (-not (Test-Path -LiteralPath $makeDir)) {
    New-Item -ItemType Directory -Path $makeDir | Out-Null
    & tar.exe -xzf $makeArchive -C $makeDir
    if ($LASTEXITCODE -ne 0) { throw "Extracao do Make falhou: codigo $LASTEXITCODE" }
}

& (Join-Path $PSScriptRoot 'run_smoke.ps1') -Clean
exit $LASTEXITCODE
