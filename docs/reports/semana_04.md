# Semana 4 — Key Expansion e controle sequencial AES-128

Data: 29/10/2026. Entrega: expansão e controle sequencial AES-128.
**Marco técnico implementado e validado; aprovação do instrutor pendente.**
Semanas 2 e 3 continuam com os respectivos aceites humanos pendentes.

## Auditoria anterior às edições

HEAD inicial `be42888`, precedido por `a4cb6df` (arquitetura v1.1).
Branch correta, árvore/index limpos, sem diff frente a be42888. Foram
conferidos histórico, diff contra main, inventário, Makefile, RTL/scripts,
arquitetura v1.1, relatório da Semana 3, backlog e README. Não houve checkout destrutivo.

Existiam package/rodada combinacional AES e TB com 2345 verificações,
XOR/TB e fluxo portátil. Não existiam Key Expansion ou controle sequencial.
Hashes SHA256 dos 36 arquivos versionados foram registrados em
`build/w04_baseline.json`, ignorado pelo Git. A regressão antes de editar
passou: XOR e 2345 checks do datapath, exit 0, sem warnings.

Não havia regras Make duplicadas por nome ou receitas sobrescritas. Havia
repetição da criação de build e da cadeia lint/compilação/simulação.
O diretório passou a ser pré-requisito order-only compartilhado; templates
Make geram uma única cadeia por suite. Alvos anteriores e ordem package→módulo
foram preservados. A regressão antiga passou novamente após o ajuste.

## Arquivos e escolhas de implementação

| Arquivo | Alteração |
|---|---|
| rtl/minisoc_aes/minisoc_aes_key_exp.sv | Pré-expansão sequencial K0..K10, banco e leitura indexada direta/inversa |
| rtl/minisoc_aes/minisoc_aes_core.sv | Auxiliar de bloco único, State, direção, contador, FSM e publicação registrada |
| tb/minisoc_aes_key_exp_tb.sv | Teste independente de chaves, validade, START, índices e abort/reset |
| tb/minisoc_aes_core_tb.sv | Teste externo de KATs, captura, BUSY, DONE, saída estável, operações consecutivas e reset |
| tb/vectors/aes128_round_keys_a.mem, aes128_round_keys_b.mem | 22 chaves oficiais como constantes públicas |
| tb/vectors/README.md | Origem e fronteiras das novas referências |
| Makefile | Receitas compartilhadas, testes key/core, regression e síntese genérica |
| scripts/run_aes_tests.ps1, run_aes_tests.sh | Regressão a partir de qualquer diretório; PowerShell permite limpeza/síntese opcionais |
| scripts/synth_aes_key.ys, synth_aes_core.ys | Síntese genérica dos novos módulos no Yosys/slang |
| docs/architecture/aes_core_semana_04.md | Contrato D20 local, interfaces, FSM/reset e contagem de ciclos |
| README.md, BACKLOG.md, índice arquitetural e syn/README.md | Situação atual, comandos e pendências |

O [contrato interno D20](../architecture/aes_core_semana_04.md) detalha a
interface. Mantiveram-se nomes oficiais de Key Expansion/datapath. O novo
core é auxiliar: `minisoc_aes_top` segue reservado ao engine de modos/memória.
A arquitetura v1.1 e o RTL/TB da Semana 3 permanecem íntegros.

Expansão usa RotWord, SubWord, Rcon e XOR encadeado, gerando uma chave por
ciclo. As onze chaves normais são lidas por índice; decrypt usa ordem reversa
com INVCIPHER. O banco invalida em novo START/reset e só expõe resultados
quando completo. As posições não recebem reset, pois serão todas sobrescritas
antes de liberar valid_o; isso não oferece zeroização física das chaves.

O núcleo captura bloco, chave e direção na mesma borda de aceitação; reutiliza
o datapath da Semana 3. START enquanto BUSY é ignorado localmente, sem fila.
DONE é pulso, distinto do futuro AES_STATUS.DONE sticky. Saída só muda na
conclusão/reset e é retida durante nova operação. Reset aborta e impede
conclusão fantasma. A integração deverá fornecer deassert de reset sincronizado.
Não foi escolhida a política de erro/concorrência do banco SPI (P25).

## Vetores e independência dos testes

- [FIPS 197 original, apêndice A.1](https://csrc.nist.gov/files/pubs/fips/197/final/docs/fips-197.pdf): onze chaves para `2b7e151628aed2a6abf7158809cf4f3c`.
- Mesmo documento, apêndice C.1: onze round keys e par plaintext/ciphertext para `000102030405060708090a0b0c0d0e0f`.
- [NIST AES_Core128](https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Standards-and-Guidelines/documents/examples/AES_Core128.pdf): quatro pares de blocos da chave A.1 em ambos os sentidos.

Esses exemplos públicos são compatíveis com o algoritmo do FIPS 197-upd1.
O endpoint do PDF atualizado apresentou timeout nesta execução; foi usada a
cópia oficial NIST da edição original para verificar os valores dos apêndices.
Não foi usado material confidencial como fixture.

Os novos TBs não importam o package do DUT nem calculam expectativa por
recorrência usando a implementação. Leem constantes oficiais ou as contêm
explicitamente. Fixtures são verificadas contra X para falhar se ausentes.
Comparações `===`/`!==`, `$fatal` e timeouts tornam os testes autochecking.

## Latência medida em ciclos

| Marco | Borda relativa à aceitação E0 |
|---|---|
| K0 capturada e BUSY da expansão alto | E0 |
| Geração K1..K10 | E1..E10 |
| Expansão completa, valid_o e done_o | Após E10: **10 ciclos** |
| Core observa conclusão e faz AddRoundKey inicial | E11 |
| Nove rodadas intermediárias | E12..E20 |
| Rodada final, data_o novo, DONE=1 e BUSY=0 | Após E21: **21 ciclos** |
| Próximo START mais cedo e captura por consumidor sequencial | E22 |

Mesma latência para encrypt e decrypt, sem cache de chaves entre operações.
Intervalo mínimo de aceitação do core: 22 ciclos. A latência de 21 ciclos
é conferida por contador externo no TB. Os estímulos usam clock artificial
de 10 ns; isso não demonstra operação a 100 MHz ou frequência do PLL.

## Comandos executados e versões

Na raiz, após ativação portátil conforme README:

```text
make -j4 smoke test-aes-dp
make -j4 smoke test-aes-dp lint-aes-key lint-aes-core
make versions
make clean
make -j4 regression
make synth-aes
```

O novo script Windows também foi executado:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_aes_tests.ps1
```

O script também foi executado com `-Clean -Synthesis` a partir de `build/`,
fora da raiz: exit 0, todos os PASS e três sínteses concluídas. A opção de
limpeza foi aplicada antes da construção; o script retornou à pasta de chamada.
Reprodução completa em um comando: adicionar `-Clean -Synthesis` ao script.
Alvos individuais: `test-aes-key`, `test-aes-core`, `lint-aes-key`,
`lint-aes-core`, `synth-aes-key`, `synth-aes-core`. O smoke permanece default.
Yosys/slang é opcional e não integra as dependências da simulação.

| Ferramenta | Versão observada |
|---|---|
| GNU Make | 4.4.1, x86_64-pc-cygwin |
| Verilator | 5.053 devel, v5.052-119-g014c9820d (mod), executável verilator_bin |
| Icarus Verilog / vvp | 14.0 devel, s20260301-500-g2e81fcccb-dirty |
| Yosys | 0.69+154, git 30d62572e-dirty, frontend slang instalado |

## Resultados reais

| Verificação | Resultado |
|---|---|
| Regressão XOR anterior e final | PASS, 4 casos |
| Datapath preservado | PASS, 2345 checks, quatro encrypt + quatro decrypt KATs |
| Key Expansion | PASS, 535 checks, 22 chaves oficiais em ambos os percursos, índices 11..15, reset em dez pontos |
| Core sequencial | PASS, 5128 checks, 52 operações completas, cinco pares oficiais nos dois sentidos e recuperação após abort |
| Reset do core | 42 cortes: 21 posições em cada direção, desde aceitação até última rodada intermediária |
| Comandos BUSY e captura de entradas | PASS, incluindo bordas de expansão, inicial, rodada e conclusão; entradas/direção alteradas após E0 |
| Saída/DONE/operações consecutivas | PASS, retenção, pulso de um ciclo, primeiro novo START em E22, sem fila de pedidos ocupados |
| Lint Verilator e compilação Icarus | PASS, sem warnings nos fluxos RTL/TB |
| Síntese genérica dp/key/core | PASS, exit 0, zero problemas em check -assert |

As suites AES somam **8008 verificações**, além dos quatro casos XOR.
Saídas resumidas:

```text
AES DATAPATH TEST PASS: 2345 checks, 4 encrypt + 4 decrypt KATs
AES KEY EXPANSION TEST PASS: 535 checks, 22 official keys, forward/reverse, latency=10 cycles
AES SEQUENTIAL CORE TEST PASS: 5128 checks, 52 completed KATs, 42 reset cuts, latency=21 cycles
```

A síntese usa `read_slang`, `synth -noabc`, `check -assert` e `stat`, sem
PDK/SDC. Nenhum latch foi encontrado nas estatísticas finais; o core possui
FFs de controle/State/saída e banco de chaves, como esperado. Contagem de
células genéricas não é área física. Não houve teste executável Verilator,
prova formal/equivalência, STA, CDC físico ou potência.

Logs locais ignorados: `build/w04_regression.log`, `build/w04_versions.log`,
`build/aes_dp_synth.log`, `build/aes_key_synth.log`, `build/aes_core_synth.log`.
A execução do wrapper completo está em `build/w04_wrapper.log`.

## Problemas identificados e limites

Não houve falha funcional de RTL nas suites executadas. A repetição das
receitas Make foi removida sem eliminar alvos antigos. Na coleta inicial
de versões, PowerShell com ErrorAction=Stop tratou a informação de `vvp -V`
em stderr como erro da coleta; o comando foi repetido preservando o código
de saída real (zero). Isso não foi falha de simulação nem warning de RTL.

START é nível amostrado em IDLE: se mantido alto até outra borda ociosa,
inicia outra operação. Cabe ao chamador pulsá-lo. Não há ack de aceitação,
fila, cache reutilizável de chaves, reset independente por submódulo ou
detecção de falha física. Isso não fecha o contrato futuro de SPI/CDC.

Continuam OPEN P14–P27, especialmente SPI de retorno, CFB, contador CTR,
latência/ownership/clock da RAM, lock/reset do PLL, snapshots CDC, valores
de reset e concorrência do banco, tecnologia e critérios de aceite.
SPI, RAM, PLL, modos e top-level não foram implementados nesta semana.

## Auditoria final e próximos passos

Auditoria executada com PASS: 36 hashes de base conferidos, **30 arquivos
idênticos** e seis atualizações deliberadas (Makefile, README, BACKLOG, índice
arquitetural, README de síntese e origem de vetores). Há doze arquivos novos,
23 Markdown lidos e **88 links relativos válidos**, sem whitespace inválido
ou anexos confidenciais entre os entregáveis. A v1.0/v1.1, relatórios antigos,
package/datapath, TB da Semana 3 e todos os scripts existentes permanecem
idênticos. Resumo local: `build/w04_audit.json`. As suites AES registram
8008 verificações; as três sínteses retornam zero problemas e nenhum latch.

Não houve push, merge ou criação de tags. Aceite humano não foi marcado.
Semana 5 pode iniciar o SPI após respostas aos pontos de protocolo/CDC;
a futura integração deverá envolver este core com modos e acesso de memória
em `minisoc_aes_top`, preservando os quatro grupos do topo oficial.
