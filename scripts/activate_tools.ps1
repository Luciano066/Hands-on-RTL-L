# Execute com dot-source: . ./scripts/activate_tools.ps1
# Modifica somente o PATH da sessao atual; nao altera registro ou perfis.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$suiteDir = Join-Path $projectRoot '.tools/oss-cad-suite'
$makeBin = Join-Path $projectRoot '.tools/make/usr/bin'
$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCommand) { throw 'Git for Windows ausente: necessario para sh e bibliotecas MSYS.' }
$gitRoot = Split-Path -Parent (Split-Path -Parent $gitCommand.Source)
$gitUsrBin = Join-Path $gitRoot 'usr/bin'
if (-not (Test-Path -LiteralPath (Join-Path $gitUsrBin 'sh.exe'))) {
    throw "Shell POSIX nao encontrado em $gitUsrBin; consulte README.md."
}
$localPaths = @($gitUsrBin)
if (Test-Path -LiteralPath $makeBin) { $localPaths = @($makeBin) + $localPaths }
if (Test-Path -LiteralPath $suiteDir) {
    $localPaths = @((Join-Path $suiteDir 'bin'), (Join-Path $suiteDir 'lib')) + $localPaths
    # Para lint, o executavel nativo aceita as mesmas opcoes e dispensa
    # o lancador Perl, cujo Pod::Usage nao acompanha todo Git for Windows.
    $env:VERILATOR = 'verilator_bin'
    $env:VERILATOR_ROOT = Join-Path $suiteDir 'share/verilator'
}
# Remove repeticoes para que ativar duas vezes nao acumule entradas locais.
$remainingPaths = $env:PATH -split ';' | Where-Object { $_ -and $_ -notin $localPaths }
$env:PATH = ($localPaths + $remainingPaths) -join ';'
