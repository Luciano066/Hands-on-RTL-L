# MiniSoC AES — arquitetura, datapath e núcleo sequencial

A Semana 1 validou o ambiente com uma XOR. A Semana 2 recebeu uma
[arquitetura v1.1](docs/architecture/arquitetura_v1.1.md) revisada após leitura
do Block Guide v1.0.0; **segue sem apresentação/aceite registrados**.
A Semana 3 implementa transformações e rodada combinacional AES-128
forward/inverse, com testes autochecking. A Semana 4 acrescenta expansão de
chave e núcleo sequencial de bloco único, testados em ambos os sentidos.
O SoC integrado ainda não existe; aceite do instrutor permanece pendente.

Em **30/10/2026**, o desafio obrigatório acrescenta três módulos
combinacionais com os nomes `minisoc_aes_sbox`, `minisoc_aes_sub_bytes` e
`minisoc_aes_shift_rows`. Eles reutilizam o package existente, com byte 0 do
State em `[127:120]`. Datapath, expansão e core sequencial foram preservados.
Veja o [relatório atualizado da Semana 2](docs/reports/semana_02.md) e o
[relatório histórico de 09/10](docs/reports/semana_02_historico_2026-10-09.md).

## Desafio de 30/10 e execução em um comando

No Windows com o toolchain portátil existente, este comando executa lint,
compilação e todas as suítes, incluindo o novo desafio:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_aes_tests.ps1 -Clean
```

Com as ferramentas no PATH: `make -j4 regression` ou
`bash scripts/run_aes_tests.sh`. Para somente os três módulos:
`make test-aes-transforms`; lint isolado: `make lint-aes-transforms`.
Falhas interrompem o alvo e retornam código diferente de zero.

| Módulo | Entrada | Saída | Função reutilizada |
|---|---|---|---|
| `minisoc_aes_sbox` | `byte_i[7:0]` | `byte_o[7:0]` | `aes_sbox` |
| `minisoc_aes_sub_bytes` | `state_i[127:0]` | `state_o[127:0]` | `sub_bytes` |
| `minisoc_aes_shift_rows` | `state_i[127:0]` | `state_o[127:0]` | `shift_rows` |

Os três módulos usam atribuições contínuas, sem clock, reset ou armazenamento.
`s[row,col]` corresponde ao byte `row+4*col`. O novo TB realiza **647 checks**:
256 entradas da S-box, 256 estados SubBytes cobrindo todas as posições,
comparações individuais de SubBytes/ShiftRows nas rodadas 1 e 10 do
Apêndice B da FIPS-197 e 131 casos de permutação. As constantes e a origem
pública estão documentadas em [tb/vectors](tb/vectors/README.md).

## Cronograma de 13 semanas e revisão com DV

O [BACKLOG](BACKLOG.md#cronograma-de-13-semanas) passa a organizar o trabalho
em **13 semanas**, preservando separadamente as evidências das etapas antigas.
Os marcos informados são **04/12/2026** e **08/01/2027**. A data inicial,
eventuais recessos e o conteúdo oficial de cada marco ainda precisam de
confirmação; a distribuição das atividades no backlog é uma proposta de
trabalho, sem datas semanais presumidas.

O contato com o verificador deve cobrir agora as portas dos três módulos,
ordem dos bytes e os vetores oficiais; antes de cada marco, revisar evidências
e divergências. **Nome, canal, datas e retornos ainda não estão registrados**.
A pauta e o quadro de contatos estão no
[relatório de 30/10](docs/reports/semana_02.md#6-dúvidas-e-contato-com-o-verificador).
Não há contato ou aceite atribuído ao parceiro nesta correção.

## Documentação vigente

- [Arquitetura v1.1](docs/architecture/arquitetura_v1.1.md): contratos, quatro grupos de portas, clocks, RAM, SPI, modos e interface do datapath.
- [Retomada, auditoria e checklist de defesa](docs/reports/semana_02_retomada.md).
- [ADRs e supersessão das decisões antigas](docs/architecture/decisoes_semana_02.md).
- [Pendências e perguntas OPEN](docs/spec/pendencias.md).
- [Semana 3: implementação e testes reais](docs/reports/semana_03.md).
- [Semana 4: expansão, controle e evidências](docs/reports/semana_04.md).
- [Contrato interno do núcleo sequencial](docs/architecture/aes_core_semana_04.md).
- [Backlog](BACKLOG.md).

O contrato revisado prevê AES-128 cipher/inverse, seis modos, 1..256 blocos
em RAM 1024 x 32 in-place; SPI Mode 0 com frames de 40 bits configura/monitora
o sistema. MEMORY DATA transfere os blocos. PLL, memória, SPI, modos e
engine integrado `minisoc_aes_top` permanecem para implementação posterior.
`minisoc_aes_core` é o auxiliar sequencial de um bloco, com a interface da
Semana 4; não altera as portas oficiais do MiniSoC.

A [arquitetura v1.0](docs/architecture/arquitetura_v1.0.md) e os materiais de
defesa de 09/10 são históricos superados. Seu mapa, frame de 48 bits, máscaras,
domínio do banco e cronograma não são contratos vigentes. O PDF confidencial
e a revisão técnica recebidos não integram o repositório.

## Núcleo sequencial e regressão completa

Com o toolchain ativado, `make -j4 regression` executa XOR, transformações,
datapath, Key Expansion e core. Em 30/10 foram observadas **8.655 verificações AES PASS**,
além dos quatro casos XOR, sem warnings. Key Expansion: 535 checks e
22 chaves oficiais; core: 5.128 checks, 52 operações e 42 cortes por reset.
Latências locais medidas: expansão 10 ciclos; core 21 ciclos, nos dois sentidos.
O núcleo expande novamente a chave a cada operação e retém a saída até
outra conclusão/reset. DONE é um pulso local; START durante BUSY é ignorado.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_aes_tests.ps1 -Clean -Synthesis
```

Sem `-Synthesis`, Yosys não é necessário. Alvos individuais:
`make test-aes-key`, `make test-aes-core`; síntese genérica: `make synth-aes`.
`bash scripts/run_aes_tests.sh` executa a regressão e localiza a raiz.
A síntese genérica anterior de dp/key/core passou com zero problemas; não valida
timing dos clocks do PLL. Consulte o relatório da Semana 4 para comandos,
versões e limites. As políticas SPI/CDC/RAM ainda OPEN não foram aprovadas.

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
|   |-- architecture/aes_core_semana_04.md
|   |-- architecture/decisoes_semana_02.md
|   |-- reports/
|       |-- semana_01.md
|       |-- semana_01_defesa.md
|       |-- semana_01_validacao.md
|       |-- semana_01_alteracoes.md
|       |-- semana_02.md
|       |-- semana_02_historico_2026-10-09.md
|       |-- semana_02_diagnostico.md
|       |-- semana_02_defesa.md
|       |-- semana_02_verificador.md
|       |-- semana_02_retomada.md
|       |-- semana_03.md
|       |-- semana_04.md
|-- rtl/minisoc_aes/{aes_transforms_pkg.sv,minisoc_aes_dp.sv}
|-- rtl/minisoc_aes/{minisoc_aes_sbox.sv,minisoc_aes_sub_bytes.sv,minisoc_aes_shift_rows.sv}
|-- rtl/minisoc_aes/{minisoc_aes_key_exp.sv,minisoc_aes_core.sv}
|-- tb/minisoc_aes_dp_tb.sv
|-- tb/minisoc_aes_transforms_tb.sv
|-- tb/{minisoc_aes_key_exp_tb.sv,minisoc_aes_core_tb.sv}
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
|   |-- run_aes_tests.ps1 / run_aes_tests.sh
|   |-- synth_aes_key.ys / synth_aes_core.ys
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
| `make test-aes-transforms` | Lint dos três módulos obrigatórios, compilação e 647 checks, incluindo FIPS B rodadas 1 e 10 |
| `make lint-aes-transforms` | Verilator `--lint-only -Wall` individualmente em S-box, SubBytes e ShiftRows |
| `make test-aes-dp` | Lint, compilação e simulação autochecking do datapath AES |
| `make lint-aes-dp` | Verilator no package e módulo de rodada |
| `make compile-aes-dp` | Lint e compilação Icarus, sem executar a simulação |
| `make sim-aes-dp` | Compila e executa o testbench AES |
| `make synth-aes-dp` | Síntese genérica opcional e check no Yosys com frontend slang |
| `make test-aes-key` / `make test-aes-core` | Lint, compilação e TBs independentes dos módulos sequenciais |
| `make lint-aes-key` / `make lint-aes-core` | Lint Verilator dos novos módulos e suas dependências |
| `make test-aes` | Quatro suítes AES: transformações obrigatórias, datapath, chaves e core |
| `make regression` | Smoke XOR e todas as suites AES, seguro para make -j4 |
| `make synth-aes` | Síntese genérica dp/key/core; alvos individuais synth-aes-key e synth-aes-core |
| `make versions` | Mostra versões reais das ferramentas |
| `make clean` | Remove somente os cinco binários .vvp conhecidos; preserva fontes, ferramentas e logs |

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
