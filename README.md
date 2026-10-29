# MiniSoC AES — arquitetura revisada e datapath

A Semana 1 validou o ambiente com uma XOR. A Semana 2 recebeu uma
[arquitetura v1.1](docs/architecture/arquitetura_v1.1.md) revisada após leitura
do Block Guide v1.0.0; **segue sem apresentação/aceite registrados**.
A Semana 3 implementa transformações e rodada combinacional AES-128
forward/inverse, com testes autochecking. O SoC integrado ainda não existe.

## Documentação vigente

- [Arquitetura v1.1](docs/architecture/arquitetura_v1.1.md): contratos, quatro grupos de portas, clocks, RAM, SPI, modos e interface do datapath.
- [Retomada, auditoria e checklist de defesa](docs/reports/semana_02_retomada.md).
- [ADRs e supersessão das decisões antigas](docs/architecture/decisoes_semana_02.md).
- [Pendências e perguntas OPEN](docs/spec/pendencias.md).
- [Semana 3: implementação e testes reais](docs/reports/semana_03.md).
- [Backlog](BACKLOG.md).

O contrato revisado prevê AES-128 cipher/inverse, seis modos, 1..256 blocos
em RAM 1024 x 32 in-place; SPI Mode 0 com frames de 40 bits configura/monitora
o sistema. MEMORY DATA transfere os blocos. PLL, memória, SPI, Key Expansion
e controlador AES permanecem para implementação posterior.

A [arquitetura v1.0](docs/architecture/arquitetura_v1.0.md) e os materiais de
defesa de 09/10 são históricos superados. Seu mapa, frame de 48 bits, máscaras,
domínio do banco e cronograma não são contratos vigentes. O PDF confidencial
e a revisão técnica recebidos não integram o repositório.

## Testar o datapath AES

Com o toolchain no PATH: `make test-aes-dp`. Esse alvo encadeia
`lint-aes-dp` → `compile-aes-dp` → `sim-aes-dp`, inclusive com `make -j4`.
Em Windows com a instalação portátil já existente:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_aes_dp.ps1
```

Resultado observado em 29/10/2026: **2.345 verificações PASS**, incluindo
quatro cifragens e quatro decifragens com constantes NIST, sem warnings no
fluxo final. Veja os [vetores e seus oráculos independentes](tb/vectors/README.md).
O TB fornece chaves e reaplica a rodada; isso não implementa uma FSM/SoC.
`bash scripts/run_aes_dp.sh` também localiza a raiz automaticamente.

`make synth-aes-dp` executa uma síntese genérica opcional com Yosys/slang.
Foi executada com zero problemas no check; não usa PDK, não mede área física
e não valida timing dos clocks do PLL. Yosys não é dependência do smoke/AES sim.

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
|   |-- architecture/arquitetura_v1.0.md
|   |-- architecture/arquitetura_v1.1.md
|   |-- architecture/decisoes_semana_02.md
|   |-- reports/
|       |-- semana_01.md
|       |-- semana_01_defesa.md
|       |-- semana_01_validacao.md
|       |-- semana_01_alteracoes.md
|       |-- semana_02.md
|       |-- semana_02_diagnostico.md
|       |-- semana_02_defesa.md
|       |-- semana_02_verificador.md
|       |-- semana_02_retomada.md
|       |-- semana_03.md
|-- rtl/minisoc_aes/{aes_transforms_pkg.sv,minisoc_aes_dp.sv}
|-- tb/minisoc_aes_dp_tb.sv
|-- tb/vectors/README.md
|-- rtl/smoke_top.sv
|-- tb/tb_smoke_top.sv
|-- formal/README.md
|-- syn/README.md
|-- upf/README.md
|-- scripts/
|   |-- run_smoke.sh
|   |-- run_smoke.ps1
|   |-- run_aes_dp.sh
|   |-- run_aes_dp.ps1
|   |-- synth_aes_dp.ys
|   |-- activate_tools.ps1
|   |-- bootstrap_windows.ps1
|-- .gitattributes
|-- .gitignore
```

`build/`, `obj_dir/`, ondas e `.tools/` são artefatos locais ignorados pelo Git. A base inspecionada para a Semana 2 está em `de477dd`, com a tag `w01-v1.0`. A descrição “sem commit ou remoto” dos relatórios da Semana 1 registra o estado histórico daquela preparação. A pasta duplicada recebida foi normalizada para esta raiz; consulte o [inventário de alterações](docs/reports/semana_01_alteracoes.md).

## O que cada alvo faz

| Alvo | Comportamento |
|---|---|
| `make smoke` | Verifica dependências, lint, compila, simula e anuncia sucesso |
| `make lint` | Verifica ferramentas e executa Verilator no RTL |
| `make compile` | Inclui lint e gera build/smoke.vvp com Icarus |
| `make sim` | Inclui lint e compilação antes de executar vvp |
| `make test-aes-dp` | Lint, compilação e simulação autochecking do datapath AES |
| `make lint-aes-dp` | Verilator no package e módulo de rodada |
| `make compile-aes-dp` | Lint e compilação Icarus, sem executar a simulação |
| `make sim-aes-dp` | Compila e executa o testbench AES |
| `make synth-aes-dp` | Síntese genérica opcional e check no Yosys com frontend slang |
| `make versions` | Mostra versões reais das ferramentas |
| `make clean` | Remove build/smoke.vvp e build/aes_dp.vvp; preserva fontes, ferramentas e logs |

As variáveis `VERILATOR`, `IVERILOG`, `VVP` e `YOSYS` permitem escolher executáveis no PATH. Para ferramentas em caminhos com espaços, prefira ativar o diretório no PATH e usar o nome do executável.

`bash scripts/run_smoke.sh` também executa o fluxo e localiza a raiz independentemente do diretório de chamada. Não depende do bit executável do arquivo em uma extração ZIP.

## Documentação e escopo futuro

- [Estudo AES, SPI e CDC](docs/reports/semana_01.md).
- [20 decisões e 60 perguntas para arguição](docs/reports/semana_01_defesa.md).
- [Comandos, versões e resultados observados](docs/reports/semana_01_validacao.md).
- [Requisitos confirmados e decisões pendentes](docs/spec/pendencias.md).
- [Backlog](BACKLOG.md).

As dúvidas funcionais originalmente abertas foram reavaliadas frente ao Block
Guide; a evolução e as questões ainda OPEN estão nas pendências. Não foram
executados síntese mapeada, formal, análise física de CDC ou medição de potência.

Referências principais: [NIST FIPS 197-upd1](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf) e [Analog Devices: SPI](https://www.analog.com/en/resources/analog-dialogue/articles/introduction-to-spi-interface.html). Distribuições usadas: [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) e [GNU Make do MSYS2](https://packages.msys2.org/packages/make).
