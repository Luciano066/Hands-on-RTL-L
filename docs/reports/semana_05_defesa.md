# Defesa técnica — Semana 5 do MiniSoC AES

Data: 18/11/2026. Implementação na branch `feat/w05-spi-control-cdc`.
**Material de estudo baseado no RTL e nas execuções reais. Aceite pendente.**
Usar em conjunto com o [relatório](semana_05.md), o
[contrato local D21–D24](../architecture/spi_semana_05.md) e a
[arquitetura v1.1](../architecture/arquitetura_v1.1.md).

## Roteiro de demonstração

Começar pelo caminho completo de um comando: mestre seleciona CS, envia
header/dado, receptor acumula 40 amostras, slot retém o candidato, evento
cruza para clk, CS alto é qualificado e o banco aplica uma única escrita.
Mostrar depois read seguido de NOP e, por último, o snapshot congelado no
START e o adaptador CDC isolado. Não apresentar o periférico como engine AES
integrado ou o TB como demonstração de timing físico.

Executar na raiz, com o toolchain portátil existente:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate_week05.ps1 -Synthesis
```

Resultados: 24.670 checks SPI/604 frames/11 consumos de configuração, 514
checks CDC, 8.655 checks AES anteriores e quatro XOR. Cinco sínteses genéricas
com zero problemas, sem latches e lint final sem warnings. Os checks SPI
incluem milhares de verificações de estabilidade por borda; não equivalem
a milhares de operações AES. Logs completos ficam em build, fora do Git.

## Perguntas e respostas para a sabatina

### 1. O que é SPI e por que foi escolhido para este projeto?

SPI é uma interface serial síncrona em que o mestre fornece o clock e
seleciona o escravo por CS. MOSI leva dados ao escravo e MISO leva dados ao
mestre; os sentidos podem operar ao mesmo tempo. Aqui, a escolha é requisito
do projeto para configurar e consultar o acelerador com poucos pinos. KEY,
IV e controles trafegam por SPI; blocos AES trafegam pela futura interface
de memória. Por exemplo, escrever KEY0 exige um frame de configuração, não
uma janela DATA_IN inventada. O módulo implementado é escravo e não gera SCLK.

### 2. Qual a diferença entre CPOL e CPHA?

CPOL define o nível ocioso do clock. CPHA define qual das duas bordas de
cada período é usada para amostragem, em relação à primeira borda após a
seleção. No Mode 0, CPOL=0 e CPHA=0: SCLK repousa baixo; a primeira subida
amostra o primeiro bit e a descida permite preparar o próximo. Confundir
essas funções deslocaria os dados em meia borda ou uma posição inteira.
Neste RTL, recepção usa `posedge spi_sclk` e transmissão usa `negedge
spi_sclk`, refletindo diretamente as duas responsabilidades.

### 3. Como funciona uma transferência Mode 0 na implementação?

O mestre coloca MOSI antes de cada subida e o mantém durante a janela de
amostragem. A subida desloca o bit recebido para shift_q e avança o contador.
O mestre amostra MISO nessa mesma subida; o escravo só prepara o bit seguinte
na descida. CS baixo delimita a transação. No TB, `bit_io` compara MISO antes
e depois da subida e usa `$fatal` se ele mudar nessa borda. Isso verifica o
comportamento lógico de fase; setup/hold elétricos ainda precisam de análise
de IO timing e não são demonstrados por delays ideais de simulação.

### 4. Por que o frame tem 40 bits?

O contrato vigente contém um bit RWb, seis bits ADDR, um bit RSV e 32 bits
DATA: 1+6+1+32=40. O header ocupa as oito primeiras amostras, seguido pelos
32 bits do dado, todos MSB-first. ADDR é índice de registrador; KEY1 fica
em 0x01, não em 0x04 como num barramento endereçado a bytes. Por exemplo,
escrever 0x11223344 em KEY0 produz o vetor de 40 bits `0x0011223344`.
Protocolos históricos de 48 bits foram superados pela v1.1 e não orientam
o receptor novo.

### 5. Como o receptor garante a ordem MSB-first e inclui o último bit?

Cada subida desloca o histórico para a esquerda e insere MOSI no bit menos
significativo. O registrador shift_q guarda os 39 bits anteriores. Quando
o contador anterior vale 39, a expressão `{shift_q[38:0], spi_mosi}` forma
o candidato completo com o quadragésimo bit atual. Capturar somente shift_q
nessa borda perderia o último bit por causa da semântica de atribuição não
bloqueante. Os testes escrevem padrões com MSB e LSB distintos, leem pelos
pinos e conferem o snapshot de KEY/IV para detectar deslocamento e troca de
palavras.

### 6. Por que o banco não aplica o comando imediatamente na 40ª subida?

Se aplicasse imediatamente, um frame de 41 bits já teria produzido efeito
antes de ser classificado como longo. O receptor publica um candidato na
40ª subida, mas o destino espera CS alto qualificado. A 41ª subida marca
long_q, retido junto ao candidato. Só então o destino decide entre comando
válido e rejeição. Isso permite rejeitar todo o frame excessivo sem rollback.
É uma escolha D22 explícita: acrescenta latência e um intervalo mínimo de
CS alto, que ainda depende da definição oficial de P14/P22.

### 7. O que ocorre com frames truncados e CS desativado no meio?

Frames de zero a 39 amostras não alcançam a condição de publicação. CS alto
limpa apenas contador/shift de framing, sem tocar no banco ou no mailbox
retido. Portanto nenhum prefixo pode virar uma escrita parcial. O TB envia
todos os comprimentos de 0 a 39 e depois lê KEY0 para confirmar que o padrão
anterior permanece. Não se exige um pulso de rejeição para cada truncamento:
sem candidato, não há evento em clk. A garantia relevante é ausência de
efeito no banco e recuperação na transação seguinte sob D21/D22.

### 8. Por que o contador satura em 41, em vez de voltar para zero?

Voltar a zero num frame longo permitiria que uma sequência excessiva
parecesse um segundo frame, potencialmente produzindo outro comando sem
CS novo. A saturação em 41 conserva a informação de excesso e impede nova
publicação dentro da mesma seleção. long_q permanece 1 até o próximo
candidato que realmente obtenha o slot. Os testes exercitam 41..48 bits,
incluindo NOP longo. O dado pode ter sido serializado para o mestre, mas
um NOP longo não confirma consumo da resposta no banco.

### 9. Como funciona a leitura em duas transações?

O primeiro frame envia RWb=1 e o índice desejado. Quando ele é aceito em
clk, o banco captura o valor em response_q e mantém pending. O segundo
frame é o NOP de escrita 0x3F. Pela escolha provisória D22, MISO devolve
o vetor `{8'h00, DATA}`: oito zeros, depois 32 bits a partir da nona amostra.
O NOP completo confirma o consumo ao retornar para clk. O formato oficial
de MISO ainda é P14; a defesa deve diferenciar a implementação testada da
especificação ainda incompleta.

### 10. Como o primeiro bit de resposta é preparado com SCLK inicialmente parado?

O primeiro bit transmitido é zero porque o prefixo D22 tem oito zeros.
Assim não é necessário carregar um MSB diferente de zero na borda de CS.
Enquanto chegam os oito bits do header NOP, pending atravessa três FF no
domínio SCLK. Na descida após a oitava amostra, o header 0x7e é reconhecido
e response_q[31] é colocado em MISO, antes da nona subida. O restante é
deslocado nas descidas seguintes. Isso resolve o caso local de clock pausado,
mas não autoriza afirmar que P14 aprovou esse prefixo ou essa posição.

### 11. O que acontece se uma resposta estiver pendente e chegar outro read?

Na política D22, o segundo read é rejeitado e a resposta anterior permanece.
Isso evita sobrescrever um dado que o mestre ainda não recebeu. Escritas
comuns podem ocorrer e mudar o banco, porém não mudam o snapshot já retido.
O TB solicita KEY0, escreve outro valor em KEY0, solicita KEY1 e em seguida
envia NOP: deve receber o valor antigo de KEY0. Depois confirma a escrita
nova numa leitura separada. Essa política não é requisito oficial; P14 deve
especificar se o contrato final terá rejeição, fila ou outra regra.

### 12. Uma leitura truncada consome a resposta?

Não na implementação D22. Carregar bits no serializador não é o mesmo que
confirmar o consumo. O banco só limpa pending ao receber um NOP de escrita
completo, com RSV=0, validado pelo receptor. Um NOP parcial ou longo pode
mostrar alguns bits em MISO, mas não altera pending. O mestre pode repetir
um NOP correto e obter o mesmo snapshot. O TB faz exatamente essa sequência
com NOP de 18 e 44 bits antes do NOP válido, prevenindo um bug comum de
ack antecipado durante o header.

### 13. Qual a finalidade de cada conjunto de registradores?

KEY0–3 compõem a chave de 128 bits. IV0–3 guardam o vetor inicial de 128
bits. COUNTER_HI/LO guardam o contador de 64 bits. NUM_BLOCKS informa a
quantidade de blocos; AES_CONTROL contém START, direção e modo. AES_STATUS
expõe ocupação, conclusão, erro e progresso. VERSION é uma constante ainda
sem número oficial. SYSTEM_CONTROL armazena seleção de memória e controles
PLL; SYSTEM_STATUS informa lock. NOP participa do retorno de leitura.
O banco de registradores existe; RAM, PLL e engine que usarão esses campos
ainda não estão conectados.

### 14. Como se reconstituem KEY, IV e COUNTER sem inverter palavras?

KEY0 corresponde a [127:96], KEY1 a [95:64], KEY2 a [63:32] e KEY3 a
[31:0]; IV segue a mesma ordem. COUNTER_HI ocupa [63:32] e LO ocupa [31:0].
No START, a concatenação usa explicitamente words_q[0] até words_q[10],
depois MODE e DECRYPT, formando 356 bits. O TB usa palavras diferentes e
compara o vetor inteiro com uma expectativa externa. Uma mutação que trocou
KEY0 e KEY1 compilou, mas foi detectada pelo teste do snapshot. Readbacks
isolados de palavras não bastariam para detectar essa inversão na montagem.

### 15. Por que NUM_BLOCKS fica com 32 bits se o máximo é 256?

Porque a validação precisa observar o valor escrito inteiro antes de
reduzi-lo. Se 513 fosse truncado a nove bits, viraria 1 e poderia ser aceito;
0x00010001 também pode virar 1. O banco mantém 32 bits e compara zero e
maior que 256 no START. Só um futuro engine, depois dessa validação, poderá
usar contadores internos menores. Nove bits representam 256; oito bits não
representam esse limite. O TB verifica 0/1/256/257/513/0x00010001 e uma
mutação com comparação truncada falhou, demonstrando a relevância do caso.

### 16. O módulo implementa os seis modos AES?

Implementa a codificação e validação dos seis modos no banco: ECB=0, CBC=1,
PCBC=2, CFB=3, OFB=4 e CTR=5. Códigos 6 e 7 produzem ERROR sem despacho.
O algoritmo de encadeamento e o processamento in-place não fazem parte do
periférico SPI. Eles exigem engine, RAM e políticas de feedback/latência.
Aceitar MODE=3 num snapshot não demonstra CFB funcionando. O TB confere
que cada código válido produz o campo correto no snapshot, e que os
reservados não produzem consumo de configuração. P15–P17 continuam abertas.

### 17. Por que START é comando e não um bit armazenado em nível alto?

Se START permanecesse alto no banco e fosse ligado diretamente ao core,
ele poderia iniciar outra operação sempre que BUSY voltasse a zero. Aqui
uma escrita com START=1 é interpretada uma vez na aplicação daquele frame.
Se válida, cria um snapshot valid/ready; START lê zero. O futuro consumidor
gera o pulso local ao consumir o snapshot. Sob backpressure, valid permanece
alto, mas só um handshake é permitido por comando. O TB conta esses consumos
e verifica que comandos ocupados não enfileiram uma segunda operação.

### 18. Qual a diferença entre o DONE do core da Semana 4 e o status SPI?

`done_o` do core é um pulso local de um ciclo. Software consultando SPI
pode demorar muitos ciclos e perder esse pulso. Por isso AES_STATUS.DONE
é persistente: permanece 1 depois da conclusão e só limpa em reset ou novo
START válido aceito. O banco recebe snapshots coerentes de status e acumula
DONE/ERROR, em vez de ligar um pulso assíncrono diretamente ao readback.
Os testes leem DONE repetidamente, rejeitam um START inválido e confirmam
que a conclusão anterior permanece. O adaptador ainda precisa ser conectado
ao futuro engine real.

### 19. Quais políticas de erro já são requisito e quais são provisórias?

É confirmado que modos reservados e N fora de 1..256 causam ERROR sem
processamento normal. A política complementar é D24: ERROR sticky até reset
ou START válido, preservação de DONE/contagem em START inválido, rejeição
interna de RO/RSV/endereço inválido e START ocupado sem fila. Não há
registradores CLR_ERROR/CLR_DONE novos. Reservados de controles são ignorados
e lidos como zero, também provisoriamente. A implementação torna essas
escolhas testáveis, mas P24/P25 só podem ser encerradas após acordo explícito
com instrutor/DV.

### 20. O que é CDC e onde ele aparece nesta etapa?

CDC é a transferência de informação entre domínios de clock sem uma borda
comum confiável para lançamento e captura. O mestre controla SCLK; o banco
usa clk; o futuro engine usará sys_clk. Mesmo clocks de frequências conhecidas
podem ter fase variável ou parar. Nesta etapa existem o transporte do frame
SCLK→clk, a resposta clk→SCLK e o adaptador bidirecional para sys_clk. Dados
e eventos têm tratamentos diferentes: eventos usam sincronizadores, dados
usam retenção e captura coerente. Testes com clocks pausados verificam o
protocolo, sem modelar analogicamente metastabilidade.

### 21. Por que dois flip-flops não bastam para um barramento multibit?

Dois FF em série reduzem a probabilidade de uma metastabilidade de um bit
se propagar, mas não fazem todos os bits do barramento representarem o mesmo
instante. Ao trocar 0x00FF por 0x0100, caminhos diferentes podem produzir uma
combinação intermediária que nunca foi enviada. No projeto, o vetor fica
congelado antes de publicar req. O destino observa req sincronizado, aguarda
guarda e captura o vetor inteiro, que só poderá mudar após ack. A estabilidade
tem de ser acompanhada de restrições físicas de atraso/skew; o handshake
RTL sozinho não resolve qualquer atraso arbitrário de roteamento.

### 22. Como funciona o handshake por toggle da mailbox?

Inicialmente req=ack=0 e o slot está livre. Na aceitação valid&&ready, a
origem congela DATA e alterna req para 1. Dois FF levam req ao destino;
ele reconhece a diferença, faz guarda, captura DATA e apresenta valid.
Quando o consumidor aceita, ack passa para 1. Dois FF devolvem ack à origem,
liberando o slot. A operação seguinte usa req=0, e assim por diante. Um
toggle é um evento persistente, não um pulso estreito. A comparação com ack
garante no máximo um evento em voo e impede reutilização prematura do vetor.

### 23. Por que um toggle sem ack pode perder comandos?

Se a origem alternar 0→1→0 antes que o destino observe 1, o destino verá
somente 0 e poderá concluir que nada aconteceu. Dois eventos se cancelam
na representação por um bit. Por isso o receptor SPI só alterna req quando
o ack sincronizado indica slot livre. Com clk parado, o primeiro frame fica
retido e o segundo completo é descartado com overrun, sem uma segunda
alternância. O TB verifica que o primeiro valor chega e o segundo não
sobrescreve outro registrador. Isso demonstra uma capacidade limitada, não
entrega ilimitada com clocks parados.

### 24. Qual é a política de backpressure e qual seu limite?

Na mailbox interna existe ready: o produtor deve manter valid/data até a
aceitação e não pode assumir consumo sem handshake. Nos pinos SPI não existe
ready oficial. D22 impõe CS alto por 12 ciclos em execução de clk e usa
um slot; se o mestre ultrapassar a capacidade, o frame extra é descartado,
com overrun interno persistente. Não há fila escondida nem garantia de
receber infinitos frames durante pausa de clk. Para mudar essa capacidade,
seria necessário acordar temporização, observabilidade do erro ou FIFO,
preservando as portas oficiais e revisando P14/P22.

### 25. Por que a implementação pede um intervalo com CS alto?

O destino precisa observar o fim do frame, distinguir 40 de 41+ bits,
capturar o vetor retido e aplicar o comando. Uma passagem muito curta de
CS alto pode nem ser observada em clk. A margem local de 12 ciclos inclui
sincronização, guarda, três observações altas e aplicação no banco. O TB
envia 24 frames consecutivos usando esse intervalo. Não são 12 clocks SCLK,
nem uma constante oficial: são ciclos ativos de clk. Se clk parar, esperar
o mesmo tempo de parede não garante progresso. A especificação definitiva
do intervalo depende de P14/P22.

### 26. Como o projeto evita operações duplicadas?

O destino compara req sincronizado com ack e só confirma uma vez por
diferença. Não reprocessa um req já confirmado. O banco recebe frame_valid
de um ciclo, e uma escrita START válida cria somente um snapshot retido.
O consumidor do snapshot confirma uma única aceitação valid&&ready. O TB
conta lançamentos, mantém ready baixo, altera o banco e tenta START ocupado:
o snapshot não muda e só um consumo ocorre. Porém dois frames idênticos
enviados quando o sistema está ocioso são dois comandos legítimos; não há
ID de transação que permita deduplicar retransmissão de software.

### 27. Como são preservadas configurações coerentes para o futuro AES?

No START aceito, KEY, IV, COUNTER, NUM_BLOCKS, MODE e DECRYPT são concatenados
na mesma borda de clk em cfg_o. Esse snapshot tem 356 bits e fica estável
até aceitação. Depois, a mailbox do adaptador congela sua própria cópia até
o consumo em sys_clk. Enquanto isso, software pode preparar novos valores
no banco sem afetar a operação em execução. O TB bloqueia ready, escreve
KEY0 e tenta novos STARTs, comparando o snapshot com a expectativa original.
Não se lê cada palavra independentemente a partir do domínio AES.

### 28. Como status e BLOCKS_DONE voltam de forma coerente?

O futuro produtor deve formar um vetor de 12 bits com flags e contagem e
mantê-lo válido até status_ready. A mailbox captura esse vetor como uma
unidade no domínio clk. O banco consome o snapshot síncrono e mantém os
bits persistentes. Sincronizar os nove bits de BLOCKS_DONE separadamente
poderia mostrar uma contagem inexistente, especialmente num carry como
127→128. O TB do adaptador compara filas de vetores completos, inclusive
com backpressure. Não está implementada a política de publicar progresso
a cada bloco; periodicidade e término antes de parar sys_clk são P23.

### 29. O que acontece se sys_clk parar com um status pendente?

Se a origem já congelou o vetor e publicou req, o destino clk pode capturá-lo
mesmo com sys_clk parado, porque o dado permanece estável. Entretanto o ack
de consumo precisa de novas bordas em sys_clk para voltar ao produtor. O
TB demonstra essa diferença: status chega ao destino enquanto a origem
está parada, mas status_ready na origem só retorna após retomada do clock.
O futuro controlador deve esperar a confirmação necessária antes de
desabilitar o domínio. A existência da mailbox não implementa automaticamente
a sequência segura de desligamento da PLL.

### 30. Como funcionam assert assíncrono e deassert sincronizado de reset?

Assert assíncrono permite limpar controle imediatamente, mesmo sem bordas
de clock. Deassert sincronizado mantém reset local até duas subidas daquele
clock, reduzindo risco de liberação perto de uma borda ativa. Cada domínio
possui `minisoc_reset_sync`, com dois FF marcados ASYNC_REG. Um domínio
parado continua em reset; não se inventam clocks para liberá-lo. As pontas
de cada mailbox precisam afirmar reset juntas para inicializar req/ack
coerentemente. Reset independente de uma ponta e sequência de relock do
AES ainda exigem projeto de integração, conforme P20.

### 31. Como é tratado reset com SCLK parado e o primeiro frame seguinte?

O banco em clk reinicializa sem depender de SCLK e mantém PLL_ENABLE=1
provisoriamente. A parte serial afirma reset de forma assíncrona e aguarda
duas subidas locais para liberar. D21 exige duas subidas de preparação com
CS alto antes do primeiro frame útil; o TB fornece essas bordas após pausar
os clocks e aplicar reset. Sem essa preparação, o primeiro frame não tem
aceitação garantida, porque pode começar enquanto o receptor está em reset.
Isso deve ser dito na defesa: é uma solução local verificável para uma
sequência de mestre ainda pendente em P21, não um contrato oficial presumido.

### 32. Por que CS limpa o framing, mas não pode limpar todo o CDC?

Se CS limpasse req ou hold_q ao fim da transação, o destino poderia perder
o comando antes de capturá-lo, especialmente com clk parado. No RTL, CS
limpa contador/shift por uma rede de reset de framing; hold_q, req, ack e
resposta pendente dependem somente do reset global/local apropriado. Isso
permite retirar CS e parar SCLK sem perder o primeiro candidato. A retirada
do reset de framing ao selecionar CS tem exigências de setup/recovery/removal
em relação a SCLK. A simulação ideal não demonstra ausência de glitches ou
metastabilidade nessa rede física.

### 33. Como a campanha de reset demonstra ausência de commits fantasmas?

O TB interrompe recepção em todos os pontos de 0 a 40 bits, inclusive com
clk e SCLK parados, afirma reset, prepara o serializador e lê KEY0. Deve
encontrar o valor de reset, nunca o padrão parcial ou o comando pendente.
Depois escreve e lê um novo valor, comprovando recuperação. Há também nove
cortes na sincronização/guarda/qualificação CS, resets com SCLK alto e
cancelamento de resposta/configuração pendentes. No adaptador, reset cancela
ambas as filas em voo e é seguido por transferências novas. Isso verifica
controle lógico; RDC físico exige análise própria.

### 34. Como foi verificada a independência dos testbenches?

O scoreboard do banco gera palavras esperadas fora do DUT e compara
readbacks SPI. O vetor esperado de configuração vem dessas palavras, não
de funções do RTL. O adaptador usa duas filas de transações independentes
e compara conteúdo/ordem no consumo. Não usa package AES, registrador interno
como valor esperado ou uma cópia da FSM como oráculo. Sondas internas são
usadas para trace e alinhamento de concorrência, não para decidir o dado
correto. Quatro mutações funcionais detectadas reforçam que os testes falham
quando os comportamentos relevantes são alterados.

### 35. O que lint e síntese provaram, e quais problemas reais encontraram?

Lint/elaboração checaram largura, uso de sinais, estruturas e conectividade.
Inicialmente apareceram um bit não usado, constante excessiva no TB e
diagnósticos de reset/sensibilidade. A síntese slang rejeitou o processo
com dois controles assíncronos e condição composta; a forma final usa uma
única rede de reset de framing. As correções foram revalidadas com Verilator
-Wall sem supressões, Icarus e Yosys. As cinco sínteses passaram no check
-assert, sem latches nas estatísticas. Isso não prova funcionamento em
silício, equivalência pós-síntese, IO timing ou confiabilidade de CDC.

### 36. O teste a 25 MHz e a síntese comprovam operação do MiniSoC a 2 GHz?

Não. O TB usa período SCLK de 40 ns em parte dos estímulos, verificando
funcionalmente a cadência de 25 MHz com clocks ideais. O clk de teste é
artificial, e Yosys sintetiza lógica genérica sem biblioteca tecnológica,
restrições IO, extração parasítica ou análise de setup/hold. Para comprovar
2 GHz seriam necessários PDK/FPGA alvo, mapeamento, restrições corretas,
STA e implementação física, além de CDC/RDC/MTBF e validação dos clocks.
As frequências da arquitetura são requisitos/metas de integração, não
resultados medidos da entrega. P27 continua aberta.

### 37. Quais decisões o instrutor ainda precisa confirmar?

P14 cobre posição de MISO, dummy, NOP, primeiro bit e leituras consecutivas.
P20/P21 cobrem reset/PLL/relock e preparação com SCLK parado. P22 define
capacidade/intervalo/overrun; P23 define status/progresso/conclusão. P24/P25
definem resets de registros, VERSION, reservados, ERROR e concorrência.
O contrato local lista valores concretos para reproduzir os testes, sempre
como D21–D24. Não houve resposta atribuída ao instrutor nem aceite humano.
Também permanecem P15–P19/P26/P27 para modos, memória e etapa física. Implementar
uma decisão provisória não encerra a pergunta que a motivou.

### 38. Como esta etapa prepara AES, PLL e RAM para a Semana 6?

O banco fornece os campos oficiais e um snapshot coerente para o engine,
enquanto o adaptador já demonstra transporte de configuração/status sem
sincronizar vetores bit a bit. SYSTEM_CONTROL expõe bits para futura PLL e
seleção de memória, mas ainda não muda clocks reais. A próxima etapa deve
resolver ownership/idle/latência da RAM, implementar PLL mock e reset
aprovados, conectar o core AES existente ao engine de modos e testar acesso
in-place. A montagem final deve preservar os quatro grupos oficiais do topo.
Um mux combinacional de clocks não substitui o protocolo seguro de handoff.

### 39. Como explicar a prioridade entre conclusão e START simultâneo?

O banco considera status_valid enquanto está ocupado e usa os flags/contagem
do snapshot de conclusão. Se o mesmo ciclo aplica um frame com START, a
política D24 rejeita o novo comando, preservando a conclusão em vez de
apagá-la por um novo BUSY. O TB alinha um frame válido com o status terminal,
verifica que não houve consumo adicional de configuração e depois lê DONE
e BLOCKS_DONE=256. Essa é uma escolha observável de concorrência, não uma
regra aprovada silenciosamente. P25 ainda pode exigir outra prioridade.

### 40. Qual é a situação objetiva da entrega?

O periférico, os slots/handshakes e o adaptador foram implementados e
verificados no repositório. Lint, regressão anterior/nova, quatro mutações
e cinco sínteses genéricas foram realmente executados. O AES anterior foi
preservado. Porém a conclusão oficial depende de resolver o protocolo
detalhado, integrar blocos reais, realizar análises físicas aplicáveis e
obter avaliação do instrutor. Não há main mergeada, tag de aceite ou push
de entrega. A apresentação deve mostrar tanto as evidências PASS quanto
os limites D21–D24, sem transformar um protótipo local em aprovação do marco.
