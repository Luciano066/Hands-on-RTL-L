# Semana 5 — SPI, registradores e CDC

Data: 18/11/2026. Base: `5c3a01b17cd7d672c856087baa5fa0466cabdf5a`.
Branch: `feat/w05-spi-control-cdc`.
**Implementação validada em simulação. O protocolo detalhado é provisório e
o aceite do instrutor está pendente.**

## 1. Objetivo e escopo

A Semana 5 implementa o periférico SPI, o banco de registradores no domínio
always-on e o transporte de comandos e snapshots entre clocks independentes.
O adaptador `clk`↔`sys_clk` foi validado isoladamente. Sua conexão com o AES,
a PLL e a RAM fica para a integração do SoC.

Os requisitos vêm da [arquitetura v1.1](../architecture/arquitetura_v1.1.md).
As questões ainda abertas estão em [pendencias.md](../spec/pendencias.md).
As escolhas locais para esta implementação estão identificadas como D21–D24.

## 2. Auditoria antes de editar

A branch de trabalho partiu de `develop` em `5c3a01b`, com a árvore limpa.
Nessa revisão, `develop` incluía o desafio combinacional (`a81d782`) e as
atualizações de cronograma (`5c3a01b`). A `main`, em `46eb75d`, tinha dois
commits documentais próprios. As referências remotas conferiam com as locais
e a divergência era de dois commits por lado.
[Comparação entre main e develop](https://github.com/Luciano066/Hands-on-RTL-L/compare/main...develop).

A busca na árvore, no diretório pai, nos anexos disponíveis e no histórico
local não encontrou RTL SPI anterior nem `semana_05_spi_rx_cdc.patch`.
Os hashes SHA256 dos **53 arquivos versionados** da base foram registrados
em `build/w05_baseline.json`.

A regressão da base foi executada com o toolchain portátil já instalado.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_aes_tests.ps1 -Clean
```

Passaram quatro casos XOR e **8.655 checks AES** (647 de transformações,
2.345 de datapath, 535 de Key Expansion e 5.128 de core), sem warnings.
O total da Semana 4 era 8.008, antes do desafio de transformações.

## 3. Requisitos confirmados e decisões provisórias

Confirmados: Mode 0, MSB-first, SCLK independente até 25 MHz, CS baixo,
MOSI na subida, MISO na descida, frame de 40 bits, mapa de índices de seis
bits, RSV=0, read seguido por NOP, banco em clk always-on, configuração
capturada, START comando, DONE persistente e validação de modo/N completos.

As decisões detalhadas e portas estão no
[contrato interno D21–D24](../architecture/spi_semana_05.md).

| ID local | Escolha implementada/testada | Pendência preservada |
|---|---|---|
| D21 | Dois FF de release por domínio; duas subidas SCLK com CS alto após reset; framing limpo por CS | P20/P21: sequência oficial, CS setup/recovery/removal e relock |
| D22 | Candidato na 40ª subida; commit após CS alto qualificado; 41+ rejeitado | P14/P22: fechamento/intervalos oficiais |
| D22 | CS alto >=12 ciclos em execução de clk entre frames | Margem RTL provisória, não intervalo extraído do guia |
| D22 | Um slot retido até ack; frame completo excedente descartado com overrun sticky interno | Capacidade/backpressure definitivo OPEN |
| D22 | MISO={00,DATA}, DATA nas amostras 9..40 do NOP de escrita | P14: formato/dummy/NOP/primeiro bit oficiais |
| D22 | Uma resposta pendente; read adicional rejeitado; NOP inválido não consome | P14: requests consecutivos |
| D23 | Mailboxes bidirecionais valid/ready, snapshots 356/12 bits, reset coordenado | P20/P23: integração e conclusão antes de parar sys_clk |
| D24 | Reset zero, exceto SYSTEM_CONTROL=2; VERSION default 0 parametrizável | P24: constantes oficiais não definidas |
| D24 | Reservados ignorados/read zero, START read zero, ERROR sticky até START válido/reset | P24: políticas oficiais |
| D24 | START ocupado rejeitado; banco pode mudar, snapshot fica congelado; conclusão vence START simultâneo | P25: concorrência oficial |

Escritas em registradores RO, endereços inválidos e frames com RSV=1 geram
um pulso interno de rejeição e preservam o banco. Um START com NUM_BLOCKS
fora de 1..256 ou modo 6/7 seta AES_STATUS.ERROR e preserva DONE e a contagem
anterior. Ao aceitar um START válido, o banco limpa DONE, ERROR e a contagem,
e seta BUSY. Escritas em SYSTEM_CONTROL durante BUSY atualizam o banco.
O controle de ownership e da mudança de divisor depende de P19/P20/P25.

## 4. Arquitetura, FSMs e handshakes

`minisoc_spi_rx` contém contador saturante e shift de recepção em SCLK.
Somente ao receber a 40ª amostra com slot livre copia os 40 bits, incluindo
o último MOSI, para hold_q e alterna req. Uma 41ª amostra marca long_q. O
framing reinicia com CS alto; mailbox/toggles não reiniciam em cada frame.

Em clk, a FSM **IDLE→GUARD→WAIT_END→IDLE** sincroniza req/CS, espera guarda e
três observações de CS alto. Publica um único frame válido ou rejeita o longo,
então confirma ack. O banco aplica o comando na borda seguinte. Isso permite
rejeitar frames longos sem precisar de clocks SCLK depois da transação. O
intervalo provisório de 12 ciclos clk inclui esse pipeline.

O slot retém `hold_q` e `long_q` enquanto `req` difere do `ack`
sincronizado. Se `clk` parar com um candidato no slot, o próximo frame
completo é descartado e seta `overrun`. O toggle e o primeiro frame ficam
retidos até o ACK.

No read, o banco captura response_q e mantém pending. Após oito clocks de
header do NOP, o serializador carrega os dados na descida e transmite MSB-first.
A confirmação de consumo é o próprio NOP completo cruzando de volta para
clk. Abort/overlength não liberam resposta. Escritas posteriores não mudam
o dado já capturado. Não se sincroniza um barramento por FF em cada bit.

`minisoc_cdc_mailbox` congela o vetor na borda em que alterna `req`. O
destino sincroniza `req`, aguarda um ciclo de guarda e mantém `valid` e os
dados estáveis até o consumo. Nesse ponto, devolve `ack`. O adaptador usa
uma mailbox de `clk` para `sys_clk` com KEY, IV, COUNTER, NUM_BLOCKS, MODE e
DECRYPT, e outra no sentido inverso para status. O testbench confere cada
direção com uma fila independente.

Reset é assert assíncrono e release local sincronizado. Com SCLK parado, a
parte serial permanece em reset até o mestre fornecer os clocks de preparação
de D21. Reset coordenado cancela candidatos, configuração e resposta, sem
commits fantasmas. Reset independente de apenas uma ponta não é suportado.
O reset de framing por CS tem requisitos físicos próprios, ainda a validar.

## 5. Mapa implementado

| Endereço | Registro | Acesso/campos |
|---|---|---|
| 00–03 | KEY0–KEY3 | R/W, 128 bits da palavra mais significativa à menos significativa |
| 04–07 | IV0–IV3 | R/W, mesma ordem |
| 08–09 | COUNTER_HI/LO | R/W, 64 bits |
| 0A | NUM_BLOCKS | R/W, 32 bits; START aceita 1..256 |
| 0B | AES_CONTROL | R/W; START[0], DECRYPT[1], MODE[4:2] |
| 0C | AES_STATUS | R; BUSY[0], DONE[1], ERROR[2], BLOCKS_DONE[11:3] |
| 0D | VERSION | R; parâmetro default 0 provisório |
| 0E | SYSTEM_CONTROL | R/W; MEM_SEL_AES[0], PLL_ENABLE[1], PLL_DIV_SEL[3:2] |
| 0F | SYSTEM_STATUS | R; PLL_LOCKED[0] |
| 3F | NOP | Retorno/ack de leitura D22, sem armazenamento de payload |

Modos 000/001/010/011/100/101 correspondem a ECB/CBC/PCBC/CFB/OFB/CTR. O
banco valida esses códigos; implementar o algoritmo de cada modo é tarefa
do futuro engine. Não foram criados CLR_DONE/CLR_ERROR/VALID_MASK/DATA_IN/OUT.

## 6. Arquivos criados e alterados

| Arquivos novos | Finalidade |
|---|---|
| rtl/minisoc_spi/minisoc_spi.sv | Banco, TX e interface interna de configuração/status |
| rtl/minisoc_spi/minisoc_spi_rx.sv | Recepção exata, framing, slot/evento/ack e overrun |
| rtl/minisoc_spi/minisoc_reset_sync.sv | Assert assíncrono/release em dois clocks locais |
| rtl/minisoc_spi/minisoc_cdc_mailbox.sv | Mailbox parametrizável retida até consumo |
| rtl/minisoc_spi/minisoc_aes_cdc.sv | Adaptador de snapshots bidirecionais isolado |
| tb/minisoc_spi_tb.sv | Scoreboard por registrador, SPI/reset/concorrência e timeout |
| tb/minisoc_spi_cdc_tb.sv | Filas independentes de configuração/status e backpressure |
| scripts/run_spi_tests.ps1 | Execução Windows, regressão/síntese opcionais |
| scripts/validate_week05.ps1 | Regressão/síntese com logs e códigos de erro preservados |
| scripts/synth_spi.ys, scripts/synth_spi_cdc.ys | Sínteses genéricas com check -assert |
| docs/architecture/spi_semana_05.md | Contrato D21–D24, interfaces e limites |
| docs/reports/semana_05.md, semana_05_defesa.md | Evidências e preparação oral |

Alterados: Makefile, README.md e BACKLOG.md. `regression-aes` preserva a
composição antiga, `regression` acrescenta as duas suítes SPI. Alvos
individuais: lint-spi, lint-spi-cdc, test-spi, test-spi-cdc e synth-spi.
O default smoke e os alvos anteriores permanecem disponíveis. A limpeza
acrescenta somente os dois binários conhecidos, sem remoção recursiva.

## 7. Estratégia de verificação

O scoreboard do banco usa valores esperados externos e leitura pelos pinos.
Não importa funções do DUT para gerar expectativas. O TB compara ordem de
palavras do snapshot e conta consumos valid/ready para detectar duplicação.
Há sondas internas opcionais de trace e de alinhamento do teste simultâneo;
elas não calculam o valor esperado. O TB de CDC usa duas filas independentes,
comparando conteúdo e ordem em cada handshake. Divergências usam `$fatal`;
há timeouts globais para detectar espera infinita. PASS aparece só ao final.

Cobertura dirigida executada:

- Todos os R/W; RO e inválidos; RSV; bits reservados; read em dois frames;
  MSB-first; retorno estável na subida; snapshots de read e configuração.
- Todos os comprimentos truncados 0..39, válidos de 40 e longos 41..48;
  NOP parcial/longo, leituras consecutivas e resposta pendente.
- 24 frames consecutivos no intervalo declarado, períodos/fases variáveis,
  incluindo SCLK de 40 ns (25 MHz), e pausa longa no meio do frame.
- clk parado, slot ocupado, descarte do excesso, recuperação sem sobrescrita;
  comandos idênticos ociosos executam uma vez cada, ocupados são rejeitados.
- NUM_BLOCKS=0/1/256/257/513/0x00010001, readback de 32 bits, modos 0..7.
- DONE/ERROR sticky, START read zero, progresso coerente e conclusão simultânea
  com START; alterações do banco não mudam snapshot sob backpressure.
- Reset em 41 pontos de recepção (0..40 bits), nove fases do pipeline clk,
  três pontos com SCLK alto, resposta/configuração pendentes e clocks parados.
- Adaptador: 102 snapshots em cada sentido antes da campanha de resets,
  valid/data retidos, ready/ack, clocks pausados, sys_clk mais rápido/lento
  que clk, frequências variáveis e nove cortes de reset, seguidos de recuperação.

Os testbenches detectaram **quatro falhas deliberadas** em cópias locais sob
`build/`: posição incorreta no TX, truncamento de NUM_BLOCKS, troca de KEY0
com KEY1 e sobrescrita do slot. Cada cópia compilou e falhou em
simulação com `$fatal` e código de saída 1. Os arquivos locais da campanha
são `build/w05_mutations.ps1` e `build/w05_mutations.json`.

## 8. Comandos, ambiente e resultados reais

Na raiz do projeto, os scripts da Semana 5 executam as suítes SPI/CDC e a
regressão completa com síntese, conforme as opções abaixo.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_spi_tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_spi_tests.ps1 -Synthesis
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate_week05.ps1 -Synthesis
```

Após ativação portátil: `make -j4 regression`, `make test-spi`,
`make test-spi-cdc` e `make synth-spi synth-aes`. A opção
`-ExecutionPolicy Bypass` se aplica ao processo PowerShell invocado.

| Ferramenta | Versão observada |
|---|---|
| Make | 4.4.1, x86_64-pc-cygwin |
| Verilator | 5.053 devel, v5.052-119-g014c9820d (mod), verilator_bin |
| Icarus/vvp | 14.0 devel, s20260301-500-g2e81fcccb-dirty |
| Yosys | 0.69+154, git 30d62572e-dirty; frontend slang |

| Verificação final | Resultado |
|---|---|
| Lint RTL anterior e SPI/CDC | Exit 0, Verilator -Wall, sem warnings e sem supressão |
| Compilação Icarus -Wall | Exit 0, sem warnings na versão final |
| XOR / transforms / dp / key / core | PASS: 4 / 647 / 2345 / 535 / 5128 |
| SPI banco/pinos | PASS: **24.670 checks, 604 frames, 11 consumos de configuração** |
| Adaptador CDC | PASS: **514 checks**, filas bidirecionais, pausas, backpressure e reset |
| Regressão anterior | **8.655 checks AES + quatro XOR**, preservada na final |
| Nova Semana 5 | **25.184 checks**; muitos checks SPI verificam estabilidade por borda |
| Regressão agregada | **33.839 checks AES/SPI/CDC + quatro XOR**, exit 0 |
| Síntese SPI / adaptador CDC | Exit 0, check -assert com zero problemas; 2025 / 786 células genéricas |
| Síntese AES dp/key/core | Exit 0, zero problemas; anteriores preservados |
| Latches | Nenhuma célula de latch nas estatísticas finais das cinco sínteses |
| Mutações auxiliares | Quatro falhas deliberadas detectadas funcionalmente |

Os logs de versões, regressão e síntese ficam em `build/` com os nomes
`w05_versions.log`, `w05_regression.log`, `w05_synthesis.log`,
`spi_synth.log`, `spi_cdc_synth.log` e `aes_{dp,key,core}_synth.log`.

## 9. Problemas encontrados e correções

A elaboração no Slang rejeitou dois controles assíncronos na mesma lista
de eventos com condição composta. O framing passou a usar uma rede de reset
combinacional única. Para resolver os avisos de lint, o shift de recepção
passou a guardar 39 bits e os estágios do sincronizador de reset passaram a
usar sinais distintos.

No Icarus, uma constante do testbench excedia a largura declarada e
`always_comb` produzia diagnósticos de sensibilidade ao selecionar posições
do banco. A constante foi ajustada e o mux de leitura passou a usar
atribuições contínuas.

Com SCLK parado, manter reset em zero desde o início da simulação deixou
`req` em X. O testbench passou a aplicar a transição 1→0 explicitamente
antes de verificar a liberação do reset. Após os ajustes, lint, compilação,
testes e síntese foram executados novamente.

## 10. Auditoria final, limitações e pendências

Os 53 hashes da base conferiram **50 arquivos idênticos** e três alterações
deliberadas: Makefile/README/BACKLOG. O contrato v1.1, contratos/relatórios
antigos, RTL/TBs AES e scripts anteriores foram preservados byte a byte.
A auditoria da entrega inicial conferiu 116 links locais em 27 arquivos
Markdown e passou em `git diff --check`. O script de auditoria grava os
resultados da execução mais recente em `build/w05_audit.json`.
O commit `b35e526` registra RTL, testes, fluxo e contrato. O commit
`f395af6` registra a versão inicial do relatório e da defesa.

Limitações materiais:

- Escolhas D21–D24 dependem de revisão: não há contrato oficial completo de
  retorno, preparação pós-reset, gaps, erros, reservados ou concorrência.
- Um slot não absorve fluxo ilimitado; excesso é descartado, com diagnóstico
  interno que ainda não tem representação no mapa/pinos oficiais.
- sys_clk/RAM/PLL/AES não estão integrados. O adaptador requer reset global
  coordenado e não resolve sozinho reset local/relock do futuro domínio AES.
- Não há controle seguro de ownership, clock gating/mux ou algoritmo dos
  modos. SYSTEM_CONTROL apenas armazena bits nesta etapa.
- Não foram executados formal, STA, CDC/RDC físico, MTBF, implementação com
  PDK/FPGA, equivalência de netlist, medição de potência ou fmax.
- O teste com SCLK de 25 MHz valida a simulação funcional nessa cadência;
  síntese genérica não comprova IO timing a 25 MHz nem clk a 2 GHz.

As decisões sobre o driver e a integração dependem da revisão de P14 e
P20–P25 pelo instrutor e por DV. P15–P19, P26 e P27 tratam dos modos, da
memória, do reset em escrita e da etapa física. O contato com DV, a
apresentação e o aceite seguem sem registro.

## 11. Critérios de aceite e próximos passos

| Critério | Situação |
|---|---|
| Auditoria, branch dedicada, preservação da base | Executado e conferido localmente |
| SPI Mode 0, 40 bits, MSB, mapa oficial | Implementado e validado funcionalmente |
| Retorno em duas transações | Implementado/testado com formato D22; oficial bloqueado por P14 |
| Slot/ack, retenção e não duplicação | Validado dentro da capacidade/intervalo declarados; P22 aberto |
| Reset/recuperação | Campanhas PASS sob D21; sequência oficial/fechamento físico P20/P21 |
| START, DONE sticky, validação 32 bits/mode | Implementado e validado; políticas complementares D24 |
| Snapshots de configuração/status | Adaptador isolado PASS; integração do sistema pendente |
| Lint, testes individuais e regressão anterior/nova | PASS real, sem warnings finais |
| Síntese genérica sem latches/problemas | PASS real em cinco unidades |
| Relatório, defesa e reprodução | Documentados; aprovação humana pendente |
| Protocolo oficial definitivo/CDC físico/timing | Pendente/bloqueado por especificação e implementação física |
| Aceite do instrutor / aprovação da Semana 5 | **Pendente; não aprovado por este relatório** |

Para a Semana 6: acordar P14/P20–P25, integrar os snapshots ao engine real,
definir RAM síncrona 1024×32 e resolver latência/idle/ownership seguro (P18/P19).
Implementar PLL mock e sua sequência de lock/reset aprovada, depois modos e
acesso in-place com preservação de feedback. Conectar top somente com os
quatro grupos oficiais de portas. Expandir DV ponta a ponta e adicionar
restrições/revisão CDC/RDC e timing antes de qualquer alegação física.

Preparação oral: [defesa técnica da Semana 5](semana_05_defesa.md).
