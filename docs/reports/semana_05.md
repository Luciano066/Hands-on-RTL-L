# Semana 5 — SPI, registradores e CDC

Data: 18/11/2026. Base: `5c3a01b17cd7d672c856087baa5fa0466cabdf5a`.
Branch: `feat/w05-spi-control-cdc`.
**Implementação local validada; protocolo detalhado provisório e aceite do
instrutor pendente. Não constitui aprovação oficial da Semana 5.**

## 1. Objetivo e escopo

Implementar o periférico SPI de configuração/status, banco always-on e
transporte coerente de comandos e snapshots entre clocks independentes.
Reutilizar a base AES das Semanas 3–4 sem modificar datapath, package,
expansão, core, vetores ou testbenches anteriores. O adaptador clk↔sys_clk
é verificável isoladamente; não há AES/PLL/RAM conectados nem SoC integrado.

Fonte funcional disponível nesta execução: arquitetura v1.1, pendências,
contrato da Semana 4 e pedido recebido. O Block Guide original confidencial
não foi reintroduzido nem publicado. Detalhes ainda OPEN foram tratados
como decisões D, sem atribuí-los ao instrutor.

## 2. Auditoria antes de editar

Raiz: `C:/Users/Luciano/Desktop/aes_spi_rtl/semana_01_aes_spi`.
Branch inicial develop, HEAD `5c3a01b`, index/árvore limpos e nenhum arquivo
não rastreado. Foram lidos README, BACKLOG, Makefile, arquitetura v1.1,
pendencias.md, relatório/contrato da Semana 4, scripts de execução/ativação
e RTL/TBs AES. O fluxo portátil já estava instalado; não houve reinstalação.

A main local estava em `46eb75d`; origin/main e origin/develop coincidiam
com as respectivas branches locais. `git rev-list --left-right --count
main...develop` retornou **2 / 2**. Desenvolvimentos exclusivos da develop:
`a81d782` (desafio combinacional) e `5c3a01b` (cronograma/contatos). Exclusivos
da main: `e17ed50` e `46eb75d`, ajustes documentais. A branch nova parte da
develop para preservar o desafio e o planejamento mais recentes, sem merge
automático. O histórico comum contém a implementação AES da Semana 4.

`git ls-remote origin refs/heads/main refs/heads/develop` falhou: conexão a
github.com:443 indisponível para o Git nativo. Na auditoria final, o conector
GitHub confirmou remotamente main=`46eb75d` e develop idêntica ao SHA completo
`5c3a01b`, com divergência **2 ahead / 2 behind**, coerente com as referências
locais. Foram usadas comparações main→develop e 5c3a01b→develop, esta última
retornando identical/0/0. Veja a
[comparação remota](https://github.com/Luciano066/Hands-on-RTL-L/compare/main...develop).
Não houve fetch/push; as consultas do conector foram somente leitura.

Não foram encontrados RTL SPI, desenvolvimento parcial ou
`semana_05_spi_rx_cdc.patch` na árvore, no diretório pai pesquisado, nos
anexos disponíveis ou no histórico local pesquisado por caminhos SPI.
Essa constatação se limita aos locais inspecionados. Não foi aplicado patch.
Foram registrados hashes SHA256 dos **53 arquivos versionados** da base em
`build/w05_baseline.json`, ignorado pelo Git.

Regressão inicial efetivamente executada antes de editar:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_aes_tests.ps1 -Clean
```

Exit 0, quatro XOR e **8.655 checks AES**: 647 transforms + 2.345 datapath +
535 Key Expansion + 5.128 core, sem warnings. O total histórico 8.008 da
Semana 4 não inclui o desafio posterior de 647 checks; ambos foram preservados.

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

Escritas RO, endereço inválido e RSV=1 não modificam registros. Geram pulso
interno de rejeição, sem inventar código de erro ou registro SPI novo. Um
START com N inválido ou modo 6/7 seta AES_STATUS.ERROR sem processamento.
Ele preserva DONE e contagem anteriores. Um START válido aceito limpa
DONE/ERROR/contagem e seta BUSY. SYSTEM_CONTROL pode ser escrito durante
BUSY; esses bits ainda não controlam clock/RAM reais. Segurança de ownership
e mudança de divisor durante operação permanece bloqueada por P19/P20/P25.

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

hold_q e long_q não podem ser sobrescritos enquanto req difere do ack
sincronizado. Se clk parar, o primeiro comando fica retido. Um segundo frame
completo não alterna req e seta overrun; não há promessa de entrega para
tráfego que exceda a capacidade. O teste demonstra esse limite, em vez de
assumir que qualquer toggle conserva eventos ilimitadamente.

No read, o banco captura response_q e mantém pending. Após oito clocks de
header do NOP, o serializador carrega os dados na descida e transmite MSB-first.
A confirmação de consumo é o próprio NOP completo cruzando de volta para
clk. Abort/overlength não liberam resposta. Escritas posteriores não mudam
o dado já capturado. Não se sincroniza um barramento por FF em cada bit.

`minisoc_cdc_mailbox` congela o vetor antes de publicar req, sincroniza req,
faz guarda, apresenta valid/data estáveis e só confirma ack quando ready
consome o vetor. O adaptador usa uma mailbox clk→sys_clk para KEY/IV/COUNTER/
N/MODE/DECRYPT e outra sys_clk→clk para status. Os TBs usam filas independentes;
não instanciam um engine fictício para alegar integração AES concluída.

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

Há **quatro mutações funcionais detectadas** em cópias locais sob build:
posição TX, NUM_BLOCKS truncado, troca de palavras e overwrite do slot.
Todas compilaram e foram rejeitadas pelos TBs com exit 1 e `$fatal`; não se
confundiu falha de compilação com detecção funcional. Fontes entregues intactas.
Scripts/resultados dessa campanha auxiliar: build/w05_mutations.ps1 e .json.

## 8. Comandos, ambiente e resultados reais

Os comandos de shell da sessão foram invocados através do prefixo RTK,
conforme instrução do ambiente. Abaixo, os comandos internos reproduzíveis:

```text
git status --short
git branch -avv
git log --left-right --oneline main...develop
git ls-remote origin refs/heads/main refs/heads/develop
git switch -c feat/w05-spi-control-cdc
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_aes_tests.ps1 -Clean
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_spi_tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_spi_tests.ps1 -Synthesis
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate_week05.ps1 -Synthesis
powershell.exe -NoProfile -ExecutionPolicy Bypass -File build/w05_mutations.ps1
```

Após ativação portátil: `make -j4 regression`, `make test-spi`,
`make test-spi-cdc`, `make synth-spi synth-aes`, `git diff --check` e
auditoria de hashes/links. Não se mudou política global do PowerShell.
`-ExecutionPolicy Bypass` vale apenas para o processo invocado.

| Ferramenta | Versão observada |
|---|---|
| Make | 4.4.1, x86_64-pc-cygwin |
| Verilator | 5.053 devel, v5.052-119-g014c9820d (mod), verilator_bin |
| Icarus/vvp | 14.0 devel, s20260301-500-g2e81fcccb-dirty |
| Yosys | 0.69+154, git 30d62572e-dirty; frontend slang |

| Verificação final | Resultado efetivamente observado |
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

Logs locais ignorados: build/w05_versions.log, w05_regression.log,
w05_synthesis.log, spi_synth.log, spi_cdc_synth.log e aes_{dp,key,core}_synth.log.
Os valores de células são genéricos; não são área física ou métrica de PDK.

## 9. Problemas encontrados e correções

A primeira tentativa de consultar o remoto falhou por conectividade do Git
nativo; o conector GitHub permitiu confirmar as branches na auditoria final.
A criação da branch precisou da autorização de escrita em metadados Git do
ambiente e então foi concluída; nenhum arquivo foi descartado.

Na implementação inicial, o lint detectou um bit de shift não utilizado,
agrupamento de bits do reset que gerava diagnóstico e CS usado como controle
assíncrono e síncrono. A síntese slang rejeitou a lista de eventos com dois
resets e condição composta. O reset de framing foi expresso por uma única
rede combinacional de reset, sem mexer em clocks. O shift passou a reter os
39 bits anteriores. **A solução final usa lint estrito sem exceções/filtros.**

Icarus também indicou excesso de dígitos numa constante do TB e sua limitação
de sensibilidade de always_comb com seleção/array. A constante foi corrigida;
o mux de leitura usa atribuições contínuas. Não se suprimiu warning de RTL.

O primeiro teste iniciou reset em nível baixo sem uma borda observável pelo
simulador no domínio parado; req permaneceu X. O TB passou a gerar uma
asserção explícita 1→0 de reset, inclusive sem SCLK, antes de testar release.
Isso evita dependência de valores iniciais implícitos na simulação.

Na coleta inicial, a saída extremamente extensa do Yosys foi preservada em
logs. O wrapper final escreve o conteúdo completo em build e mostra um
resumo, mantendo exit codes reais. Informações de versão em stderr não são
classificadas como falhas funcionais. A compilação, os TBs e a síntese foram
reexecutados após as correções.

## 10. Auditoria final, limitações e pendências

Os 53 hashes da base conferiram **50 arquivos idênticos** e três alterações
deliberadas: Makefile/README/BACKLOG. O contrato v1.1, contratos/relatórios
antigos, RTL/TBs AES e scripts anteriores foram preservados byte a byte.
A auditoria leu 27 Markdown e conferiu 116 links locais, sem anexos
confidenciais selecionados. Resultados detalhados estão em
build/w05_audit.json; `git diff --check` foi executado sem erros.

O commit `b35e526` contém RTL/testes/fluxo/contrato. O commit documental
seguinte contém relatório/defesa e atualização de situação; seu hash pode
ser consultado com `git log -2 --oneline` na branch. Não há merge na main,
tag de aceite ou push.

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

P14/P20/P21/P22/P23/P24/P25 exigem instrutor/DV antes de congelar o driver e
a integração. P15–P19/P26/P27 permanecem abertas para modos, memória, reset
em escrita e etapa física. Nenhuma pendência foi encerrada por implementação
unilateral. Contato com DV, apresentação e aceite humano não foram registrados.

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
