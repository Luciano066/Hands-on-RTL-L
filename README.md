# Acelerador AES com interface SPI — Semana 1

Entrega de estudo e preparação do ambiente. O único circuito é uma XOR combinacional; a implementação AES começa nas próximas semanas.

O fluxo aberto foi executado com sucesso em Windows x64: lint, compilação e simulação, com quatro casos autochecking e sem warnings no smoke. Consulte os [resultados e limitações](docs/reports/semana_01_validacao.md).

## Executar

Com GNU Make, shell POSIX, Verilator, Icarus Verilog e vvp disponíveis no ambiente:

```sh
make smoke
```

Para demonstrar a reconstrução:

```sh
make clean
make smoke
```

Execute os comandos separadamente; não use `make -j clean smoke`, pois limpeza e construção não devem concorrer. `make -j4 smoke` é suportado e mantém a ordem das etapas.

Saída de sucesso:

```text
SMOKE TEST PASS
Semana 1: fluxo minimo concluido com sucesso.
```

Qualquer etapa com erro faz o make retornar código diferente de zero. Dependências ausentes são informadas; não são ignoradas nem instaladas por `make smoke`.

## Windows: preparação portátil em um comando

Pré-requisitos: Windows x64, Git for Windows com `git` no PATH, PowerShell, `curl.exe` e `tar.exe` com suporte a gzip e zstd. O Git fornece o shell POSIX e as DLLs MSYS usadas pelo Make. O bootstrap não instala Git, WSL nem altera configurações globais.

Na raiz deste projeto:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap_windows.ps1
```

Esse comando baixa versões fixadas, verifica SHA256, extrai em `.tools/` e executa `make clean` seguido de `make smoke`. O download principal tem aproximadamente 600 MB; reserve alguns GB para pacote e extração. A rede só é necessária na preparação inicial. `-ExecutionPolicy Bypass` vale apenas para esse processo PowerShell.

O pacote OSS CAD Suite Windows não fornece GNU Make nem shell. O bootstrap acrescenta GNU Make do MSYS2 localmente. No Windows, a ativação seleciona `verilator_bin`, o executável nativo do Verilator, e configura `VERILATOR_ROOT`: o lançador Perl `verilator` requer módulos ausentes no Git instalado. Isso não pula lint nem muda suas opções.

Execuções posteriores, sem baixar novamente:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_smoke.ps1 -Clean
```

Para usar literalmente os alvos Make em uma sessão interativa, abra uma sessão PowerShell que permita os scripts apenas naquele processo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass
. ./scripts/activate_tools.ps1
make clean
make smoke
make versions
```

Fechar essa sessão descarta o PATH e as variáveis locais. Não há alteração de perfil, registro ou política global.

O bootstrap reutiliza downloads com SHA256 correto. Se houver falha de hash ou extração parcial, ele retorna erro; inspecione o caminho informado antes de substituir o arquivo/diretório local. Fontes nunca são sobrescritos pela instalação.

## Linux: dependências e execução

Em Debian/Ubuntu, uma opção de preparação é instalar `make`, `bash`, `verilator` e `iverilog` pelo gerenciador de pacotes; `vvp` acompanha Icarus. Exemplo a executar conscientemente nesse sistema:

```sh
sudo apt-get update
sudo apt-get install make bash verilator iverilog
make clean
make smoke
```

Essa receita Linux não foi executada nesta sessão Windows. Versões podem diferir; registre `make versions` ao validar outro ambiente. Também é possível usar uma distribuição portátil compatível com o sistema.

“Ambiente limpo” para o fluxo significa fontes sem artefatos de compilação, com dependências disponíveis. O teste foi repetido em uma cópia sem build. Um sistema operacional sem make não pode interpretar um Makefile; por isso há instruções explícitas de preparação e um bootstrap Windows separado.

## Organização

```text
.
|-- README.md
|-- BACKLOG.md
|-- Makefile
|-- docs/
|   |-- spec/pendencias.md
|   |-- architecture/README.md
|   |-- reports/
|       |-- semana_01.md
|       |-- semana_01_defesa.md
|       |-- semana_01_validacao.md
|       |-- semana_01_alteracoes.md
|-- rtl/smoke_top.sv
|-- tb/tb_smoke_top.sv
|-- formal/README.md
|-- syn/README.md
|-- upf/README.md
|-- scripts/
|   |-- run_smoke.sh
|   |-- run_smoke.ps1
|   |-- activate_tools.ps1
|   |-- bootstrap_windows.ps1
|-- .gitattributes
|-- .gitignore
```

`build/`, `obj_dir/`, ondas e `.tools/` são artefatos locais ignorados pelo Git. O repositório Git foi inicializado localmente, sem commit ou remoto. A pasta duplicada recebida foi normalizada para esta raiz; consulte o [inventário de alterações](docs/reports/semana_01_alteracoes.md).

## O que cada alvo faz

| Alvo | Comportamento |
|---|---|
| `make smoke` | Verifica dependências, lint, compila, simula e anuncia sucesso |
| `make lint` | Verifica ferramentas e executa Verilator no RTL |
| `make compile` | Inclui lint e gera build/smoke.vvp com Icarus |
| `make sim` | Inclui lint e compilação antes de executar vvp |
| `make versions` | Mostra versões reais das ferramentas |
| `make clean` | Remove somente build/smoke.vvp; preserva fontes, ferramentas e logs |

As variáveis `VERILATOR`, `IVERILOG` e `VVP` permitem escolher executáveis no PATH. Para ferramentas em caminhos com espaços, prefira ativar o diretório no PATH e usar o nome do executável.

`bash scripts/run_smoke.sh` também executa o fluxo e localiza a raiz independentemente do diretório de chamada. Não depende do bit executável do arquivo em uma extração ZIP.

## Documentação e escopo futuro

- [Estudo AES, SPI e CDC](docs/reports/semana_01.md).
- [20 decisões e 60 perguntas para arguição](docs/reports/semana_01_defesa.md).
- [Comandos, versões e resultados observados](docs/reports/semana_01_validacao.md).
- [Requisitos confirmados e decisões pendentes](docs/spec/pendencias.md).
- [Backlog](BACKLOG.md).

AES-128 é exemplo didático; variantes, cifragem/decifragem, SPI, reset, frequências, registradores, arquitetura, S-box, Key Expansion e CDC não foram fixados. Não foram executados síntese, formal, análise física de CDC ou medição de potência. PDK e ferramentas oficiais do instrutor permanecem a informar.

Referências principais: [NIST FIPS 197-upd1](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf) e [Analog Devices: SPI](https://www.analog.com/en/resources/analog-dialogue/articles/introduction-to-spi-interface.html). Distribuições usadas: [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) e [GNU Make do MSYS2](https://packages.msys2.org/packages/make).
