# Semana 2 — desafio obrigatório de 30/10/2026

Data: 30/10/2026. Branch: `develop`; base auditada: `5043910`.
**Resultado técnico: três módulos combinacionais implementados e testados;
apresentação ao verificador e aceite do professor continuam pendentes.**

## 1. Escopo e histórico

O desafio informado exige `minisoc_aes_sbox`, `minisoc_aes_sub_bytes` e
`minisoc_aes_shift_rows`, com byte 0 do State em `[127:120]`. A correção expõe
as funções AES existentes como módulos e acrescenta verificação isolada.
Datapath e núcleo sequencial já validados foram preservados.

O relatório anterior foi copiado integralmente para
[semana_02_historico_2026-10-09.md](semana_02_historico_2026-10-09.md).
Seu SHA256, idêntico ao arquivo de origem antes da substituição, é
`4f47959cccd777f092d3d3003fcdfb1a00d2c1e71957d8de4d53cad12342f488`.
A [arquitetura v1.1](../architecture/arquitetura_v1.1.md) e os relatórios
[da rodada](semana_03.md) e [do core](semana_04.md) continuam como evidência
das implementações anteriores, sem confundir sua numeração com o replanejamento.

O checkout inicial estava limpo na `main`, em `46eb75d`; foi trocado para a
`develop` solicitada, também limpa, antes das edições. Não foi feito merge.
O Block Guide confidencial não está no workspace desta revisão e não foi
relido nem reproduzido. Para integração, foram consultados os contratos e
as pendências já registrados no repositório. Os vetores novos vêm somente
da fonte pública [FIPS 197-upd1 do NIST](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf).

## 2. Auditoria do RTL e interfaces

`aes_transforms_pkg.sv` já implementa S-box por `case` completo com `default`,
SubBytes sobre os 16 bytes e ShiftRows com deslocamento por linha. As funções
são automáticas, atribuem todas as posições e não contêm relógio, estado,
inicialização ou atraso. O empacotamento já era o exigido:

```text
byte[i] = state[127-8*i -: 8]
s[row,col] = byte[row+4*col]
byte[0] = state[127:120]
```

| Módulo / arquivo em `rtl/minisoc_aes/` | Entrada | Saída | Implementação |
|---|---|---|---|
| `minisoc_aes_sbox.sv` | `byte_i[7:0]` | `byte_o[7:0]` | `assign` de `aes_transforms_pkg::aes_sbox` |
| `minisoc_aes_sub_bytes.sv` | `state_i[127:0]` | `state_o[127:0]` | `assign` de `aes_transforms_pkg::sub_bytes` |
| `minisoc_aes_shift_rows.sv` | `state_i[127:0]` | `state_o[127:0]` | `assign` de `aes_transforms_pkg::shift_rows` |

Essas são as interfaces públicas desta implementação. Não existem portas de
clock/reset/enable/valid, registradores ou latência em ciclos. As saídas seguem
as entradas combinacionalmente. `#1` aparece apenas no TB para acomodação da
simulação. O package deve ser compilado antes dos módulos consumidores.

O reaproveitamento evita manter uma segunda implementação funcional de AES.
O `git diff --exit-code` confirmou ausência de alterações no package,
`minisoc_aes_dp.sv`, `minisoc_aes_key_exp.sv`, `minisoc_aes_core.sv` e nos
três TBs anteriores. Permanecem os contratos locais: expansão em 10 ciclos,
core em 21 ciclos, cipher/inverse, reset/abort e pulso DONE.

## 3. Arquivos da correção

| Arquivo | Alteração |
|---|---|
| `rtl/minisoc_aes/minisoc_aes_sbox.sv` | Novo módulo combinacional de um byte |
| `rtl/minisoc_aes/minisoc_aes_sub_bytes.sv` | Novo módulo combinacional de 128 bits |
| `rtl/minisoc_aes/minisoc_aes_shift_rows.sv` | Novo módulo combinacional de 128 bits |
| `tb/minisoc_aes_transforms_tb.sv` | Novo TB autochecking dos três módulos, sem importar funções do DUT |
| `tb/vectors/README.md` | Origem, serialização e estados oficiais do Apêndice B |
| `Makefile` | Alvos lint/compile/sim/test de transforms; inclusão em test-aes/regression e clean |
| `docs/reports/semana_02.md` | Este relatório de 30/10 |
| `docs/reports/semana_02_historico_2026-10-09.md` | Cópia integral do relatório anterior |
| `README.md` / `BACKLOG.md` | Interfaces, comando único, resultados, proposta de 13 semanas, marcos e contatos pendentes |

Os scripts existentes `run_aes_tests.ps1` e `run_aes_tests.sh` não precisaram
de alteração: chamam `regression`, que agora inclui o desafio. Nenhuma função
adicional do SoC foi implementada.

## 4. Testbench e referências oficiais

O novo TB instancia os três módulos reais. A constante `FIPS_SBOX` contém a
tabela 4 da FIPS 197, com 256 valores de referência. A S-box isolada percorre
00..ff; SubBytes recebe 256 estados de bytes distintos, exercitando cada valor
em cada posição. Não se usa uma função do DUT para calcular o esperado.

Para SubBytes e ShiftRows, o TB compara individualmente as constantes do
**Apêndice B**, páginas impressas 34–35 / físicas 42–43 do PDF atualizado:

| Rodada | Início da rodada | Após SubBytes | Após ShiftRows |
|---|---|---|---|
| 1 | `193de3bea0f4e22b9ac68d2ae9f84808` | `d42711aee0bf98f1b8b45de51e415230` | `d4bf5d30e0b452aeb84111f11e2798e5` |
| 10 | `eb40f21e592e38848ba113e71bc342d2` | `e9098972cb31075f3d327d94af2e2cb5` | `e9317db5cb322c723d2e895faf090794` |

Plaintext do exemplo: `3243f6a8885a308d313198a2e0370734`; chave:
`2b7e151628aed2a6abf7158809cf4f3c`. A rodada 1 começa após o AddRoundKey
inicial. ShiftRows recebe a constante oficial após SubBytes diretamente,
sem depender da saída produzida por SubBytes no teste. O TB anterior usa
outro exemplo NIST, preservado; ele sozinho não comprovava o Apêndice B.

Há ainda 128 vetores one-hot, uma permutação com bytes `00..0f` e estados
zero/um para ShiftRows. Total: **647 checks** = 256 S-box + 256 SubBytes +
4 comparações oficiais + 131 permutações. Comparações usam `!==` e falham
por `$fatal(1, ...)`, com diagnóstico de obtido/esperado e watchdog.

## 5. Comandos, testes executados e resultados

Comando completo no Windows, com a instalação portátil existente:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_aes_tests.ps1 -Clean
```

Com toolchain no PATH, `make -j4 regression` executa o mesmo conjunto;
`bash scripts/run_aes_tests.sh` também localiza a raiz. Para a suíte isolada:

```sh
make test-aes-transforms
make lint-aes-transforms
```

`test-aes-transforms` encadeia lint dos três tops → compilação Icarus → vvp.
O package é listado primeiro. O encadeamento continua válido com `make -j4`.
Os dois últimos comandos são alternativas de inspeção, não etapas manuais
necessárias ao comando completo.

| Execução em 30/10/2026 | Resultado observado |
|---|---|
| Regressão anterior às edições, mesmo script com `-Clean` | Exit 0; 8.008 checks AES + quatro casos XOR |
| Regressão ampliada pelo comando único, após a correção | Exit 0; 8.655 checks AES + quatro casos XOR |
| `make -j4 test-aes-transforms` | Exit 0; 647 checks, S-box 256/256, FIPS B rodadas 1 e 10 |
| Verilator individualmente em S-box, SubBytes e ShiftRows | `--lint-only -Wall`, exit 0; sem erros/warnings |
| Datapath anterior | 2.345 checks; quatro cifragens + quatro decifragens KAT |
| Key Expansion anterior | 535 checks, 22 chaves oficiais; latência 10 ciclos |
| Core sequencial anterior | 5.128 checks, 52 operações concluídas, 42 cortes por reset; latência 21 ciclos |
| Quatro ensaios negativos em cópias sob `build/challenge_3010/` | Todos detectados por `$fatal`, vvp exit 1 e sem PASS final |

Os ensaios negativos alteraram: S-box somente em `ff`; ordem dos bytes de
SubBytes; ShiftRows substituído por identidade; último bit da referência
ShiftRows da rodada 10. Isso confirma a detecção de falhas nos três módulos
e na comparação específica da rodada 10. O script local de auditoria foi
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File build/check_challenge.ps1`;
scripts, cópias e logs desses ensaios ficam ignorados em `build/`. A suíte
positiva distribuída não depende deles. Os RTL/TBs reais não foram mutados.

Trecho da execução positiva:

```text
SBOX EXHAUSTIVE PASS: 256 inputs; SubBytes: 256 states, all 16 lanes
FIPS APPENDIX B ROUND 1 PASS: SubBytes and ShiftRows
FIPS APPENDIX B ROUND 10 PASS: SubBytes and ShiftRows
AES TRANSFORMS TEST PASS: 647 checks, S-box 256/256, FIPS B rounds 1 and 10
AES KEY EXPANSION TEST PASS: 535 checks, 22 official keys, forward/reverse, latency=10 cycles
AES SEQUENTIAL CORE TEST PASS: 5128 checks, 52 completed KATs, 42 reset cuts, latency=21 cycles
AES DATAPATH TEST PASS: 2345 checks, 4 encrypt + 4 decrypt KATs
SMOKE TEST PASS
```

A ordem das mensagens entre suítes pode variar devido ao `-j4`.
Ferramentas realmente usadas: GNU Make 4.4.1; Verilator 5.053 devel,
`v5.052-119-g014c9820d (mod)`, executável `verilator_bin`; Icarus/vvp 14.0
devel, `s20260301-500-g2e81fcccb-dirty`.

**Warnings e ajuste durante a validação:** nenhum warning no fluxo positivo
final de lint/compilação/simulação. Não foi usada supressão geral de warnings
nem `-Wno-fatal`. A primeira execução do TB novo falhou porque os valores
e5/e6 da tabela de referência foram transcritos em ordem trocada; a constante
foi corrigida e toda a regressão passou. Não houve alteração no RTL legado.
Os relatórios informativos do Verilator e as mensagens `$finish` não são
warnings. Verilator foi usado para lint; a execução do TB foi feita por vvp.

A conferência documental passou em cinco arquivos Markdown UTF-8, com 37
links relativos válidos, 13 semanas no plano, os dois marcos e cópia histórica
idêntica à base. `git diff --check` não apontou erros de whitespace.

## 6. Dúvidas e contato com o verificador

Perguntas para revisão das seções **1–3 e 8** do Block Guide. São dúvidas
de aceite e integração a partir do enunciado e dos registros existentes,
sem atribuir respostas ao professor nem reproduzir o documento confidencial:

| Seção | Pergunta a confirmar |
|---|---|
| 1 | Como o desafio de 30/10 é avaliado separadamente do MiniSoC completo e do aceite arquitetural ainda pendente? |
| 2 | Qual é a data inicial das 13 semanas, quais recessos se aplicam e quais entregáveis/critérios correspondem a 04/12/2026 e 08/01/2027? |
| 3 | Além dos nomes de módulos exigidos, há nomes de portas obrigatórios? As interfaces `byte_i/byte_o` e `state_i/state_o` propostas são aceitas pelo ambiente do parceiro? |
| 8 | O encapsulamento combinacional das funções do package atende à forma de entrega? Confirmar convenção por colunas/byte 0 no MSB, fronteiras dos estados das rodadas e tratamento esperado de X/Z no ambiente de DV. |

As pendências de integração [P14–P27](../spec/pendencias.md) continuam abertas,
incluindo SPI, reset/CDC, RAM, modos, ferramentas e critérios físicos. Elas
não bloqueiam a verificação puramente combinacional desta entrega.

| Contato previsto | Pauta | Registro efetivo em 30/10 |
|---|---|---|
| Após preparar o desafio de 30/10 | Interfaces dos três módulos, ordem dos bytes, tabela S-box, FIPS B e comando único | Parceiro/nome/canal/data/retorno não informados; revisão pendente |
| Antes do marco de 04/12/2026 | Escopo do marco, contratos de integração e divergências de DV | Planejado; não realizado nesta correção |
| Antes do marco de 08/01/2027 | Regressão, evidências, correções e condições de aceite | Planejado; não realizado nesta correção |

Após cada contato, registrar nome, data/canal, revisão/commit apresentado,
retorno, responsáveis e pendências. Não há mensagem enviada nem concordância
presumida. O [pacote antigo do verificador](semana_02_verificador.md) permanece
histórico; o material atual para esta pauta é este relatório e o TB novo.

## 7. Planejamento, limites e versionamento

README e [BACKLOG](../../BACKLOG.md#cronograma-de-13-semanas) agora distinguem
o plano de **13 semanas** das entregas históricas. Os marcos de **04/12/2026**
e **08/01/2027** estão registrados; calendário semanal e conteúdo oficial
dos marcos seguem a confirmar. A distribuição de atividades é uma proposta.

Esta correção não implementa SPI, RAM, PLL, modos de operação, integração,
UPF ou otimizações. Não houve nova síntese, STA, análise física de CDC ou
medição de potência. Lint e simulação não demonstram timing físico nem
aceite humano. O Block Guide e a revisão confidencial não integram a entrega.

Entrega destinada a um commit local na `develop`, com os fontes e documentos
listados na seção 3. Sem push, merge ou tag. Aprovação do professor e revisão
do parceiro dependem de registros reais posteriores.
