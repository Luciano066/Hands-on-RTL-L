# Defesa técnica — Semana 5 do MiniSoC AES

Data: 18/11/2026. Implementação na branch `feat/w05-spi-control-cdc`.
**Material de estudo baseado no RTL e nas execuções reais. Aceite pendente.**
Usar em conjunto com o [relatório](semana_05.md), o
[contrato local D21–D24](../architecture/spi_semana_05.md) e a
[arquitetura v1.1](../architecture/arquitetura_v1.1.md).

## Roteiro de demonstração

1. Escrever KEY0 e acompanhar o frame desde CS baixo até a atualização do
   banco em `clk`. Observar a diferença entre a 40ª amostra e o commit.
2. Ler KEY0 com uma solicitação seguida de NOP. Identificar a nona subida de
   SCLK, quando o mestre amostra o primeiro bit do dado em MISO.
3. Acionar START e acompanhar o snapshot enquanto o consumidor mantém
   `ready` baixo. Usar o TB do adaptador para mostrar a travessia até `sys_clk`.

Executar na raiz, com o toolchain portátil existente:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate_week05.ps1 -Synthesis
```

Os 604 frames do TB SPI somaram 24.670 verificações, incluindo estabilidade
por borda, e 11 consumos de configuração. O TB CDC passou em 514 verificações.
A regressão anterior passou em 8.655 verificações AES e quatro casos XOR.
O lint terminou sem warnings e as cinco sínteses genéricas passaram no
`check -assert`, sem latches. Os logs ficam em `build/`.

## Perguntas e respostas para a sabatina

### 1. O que é SPI e por que foi escolhido para este projeto?

SPI é uma interface serial síncrona. O mestre fornece SCLK, seleciona o
periférico por CS e envia comandos em MOSI. O periférico pode devolver dados
em MISO durante o mesmo frame. No MiniSoC, quatro sinais bastam para acessar
chave, IV, controles e status. Os blocos a cifrar ou decifrar ficam a cargo
da interface de memória prevista na arquitetura.

### 2. Qual a diferença entre CPOL e CPHA?

- CPOL define o nível de SCLK em repouso. Com CPOL=0, o clock fica baixo.
- CPHA indica se a amostragem ocorre na primeira ou na segunda borda de
  cada período. Com CPHA=0, ela ocorre na primeira.

Com ambos em zero (Mode 0), a primeira borda é de subida. O RTL recebe com
`posedge spi_sclk` e prepara o bit seguinte de MISO com `negedge spi_sclk`.

### 3. Como funciona uma transferência Mode 0 na implementação?

O mestre coloca MOSI antes de cada subida e o mantém durante a janela de
amostragem. A subida desloca o bit recebido para shift_q e avança o contador.
O mestre amostra MISO nessa mesma subida; o escravo só prepara o bit seguinte
na descida. CS baixo delimita a transação. No TB, `bit_io` compara MISO antes
e depois da subida e usa `$fatal` se ele mudar nessa borda. Isso verifica o
comportamento lógico de fase; setup/hold elétricos ainda precisam de análise
de IO timing e não são demonstrados por delays ideais de simulação.

### 4. Por que o frame tem 40 bits?

O cabeçalho tem oito bits (`RWb`, `ADDR[5:0]`, `RSV`) e precede os 32 bits
de `DATA`. A transmissão é MSB-first. Com `RWb=0`, `ADDR=0` e `RSV=0`, o
mestre escreve `0x11223344` em KEY0 enviando `0x0011223344`. Como `ADDR`
é um índice de registrador, KEY1 vem logo depois, no endereço `0x01`.

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

Na 40ª subida, o receptor ainda pode receber outro bit. Por isso ele retém
os 40 bits e o circuito em `clk` espera a confirmação de CS alto. Se houver
uma 41ª subida com CS baixo, `long_q` marca o frame para rejeição. A espera
evita aplicar uma escrita que precisaria ser desfeita. O intervalo mínimo
de CS alto adotado em D22 continua sujeito a P14/P22.

### 7. O que ocorre com frames truncados e CS desativado no meio?

Ao subir antes da 40ª amostra, CS reinicia o contador e o registrador de
deslocamento. O toggle de publicação permanece no valor anterior, de modo
que o banco segue sem um comando novo. O TB percorre comprimentos de 0 a 39
bits e lê KEY0 para confirmar que o conteúdo anterior foi preservado.

### 8. Por que o contador satura em 41, em vez de voltar para zero?

Voltar a zero num frame longo permitiria que uma sequência excessiva
parecesse um segundo frame, potencialmente produzindo outro comando sem
CS novo. A saturação em 41 conserva a informação de excesso e impede nova
publicação dentro da mesma seleção. long_q permanece 1 até o próximo
candidato que realmente obtenha o slot. Os testes exercitam 41..48 bits,
incluindo NOP longo. O dado pode ter sido serializado para o mestre, mas
um NOP longo não confirma consumo da resposta no banco.

### 9. Como funciona a leitura em duas transações?

No primeiro frame, `RWb=1` seleciona a leitura de `ADDR`. O banco guarda
o valor em `response_q`. No segundo, o mestre envia um NOP de escrita no
endereço `0x3F` e recebe `{8'h00, DATA}` em MISO. Pela regra provisória D22,
o dado começa na 9ª amostra e o NOP completo confirma o consumo em `clk`.
O formato definitivo de MISO continua aberto em P14.

### 10. Como o primeiro bit de resposta é preparado com SCLK inicialmente parado?

MISO começa em zero. Os oito clocks do cabeçalho dão tempo para o sinal de
resposta pendente atravessar três flip-flops em SCLK. Se o cabeçalho for
`0x7e` e houver resposta, a descida após a 8ª amostra coloca
`response_q[31]` em MISO. O mestre lê esse bit na 9ª subida e os restantes
nas subidas seguintes. O prefixo de zeros e a posição do dado pertencem a D22.

### 11. O que acontece se uma resposta estiver pendente e chegar outro read?

Considere a sequência do TB. O mestre solicita KEY0, escreve um valor novo
em KEY0, pede KEY1 e envia NOP. D22 rejeita o pedido de KEY1 e o NOP devolve
KEY0 como ele estava no instante da primeira leitura. Uma solicitação
posterior a KEY0 devolve a palavra atualizada. O tratamento definitivo de
leituras sobrepostas continua em P14.

### 12. Uma leitura truncada consome a resposta?

Em D22, o banco libera a resposta somente após validar um NOP de escrita
com 40 bits e `RSV=0`. O TB envia NOPs de 18 e 44 bits antes de um NOP
válido. Embora o mestre possa ver bits da resposta nas tentativas
anteriores, o último NOP ainda precisa devolver o dado completo.

### 13. Qual a finalidade de cada conjunto de registradores?

| Grupo | Função |
|---|---|
| KEY0–3, IV0–3 | Chave e vetor inicial, ambos de 128 bits |
| COUNTER_HI/LO, NUM_BLOCKS | Contador de 64 bits e quantidade de blocos |
| AES_CONTROL, AES_STATUS | START, direção e modo. Ocupação, conclusão, erro e progresso |
| SYSTEM_CONTROL, SYSTEM_STATUS | Seleção da memória, ajustes da PLL e indicação de lock para a futura integração |
| VERSION, NOP | Identificação com valor oficial em aberto e comando de retorno de leitura |

### 14. Como se reconstituem KEY, IV e COUNTER sem inverter palavras?

KEY0 corresponde a [127:96], KEY1 a [95:64], KEY2 a [63:32] e KEY3 a
[31:0]; IV segue a mesma ordem. COUNTER_HI ocupa [63:32] e LO ocupa [31:0].
No START, a concatenação usa explicitamente words_q[0] até words_q[10],
depois MODE e DECRYPT, formando 356 bits. O TB usa palavras diferentes e
compara o vetor inteiro com uma expectativa externa. Uma mutação que trocou
KEY0 e KEY1 compilou, mas foi detectada pelo teste do snapshot. Readbacks
isolados de palavras não bastariam para detectar essa inversão na montagem.

### 15. Por que NUM_BLOCKS fica com 32 bits se o máximo é 256?

Truncar `513` ou `0x00010001` para nove bits produziria `1`. Por isso o
banco compara os 32 bits escritos com os limites de 1 a 256 na hora do
START. Depois dessa validação, nove bits bastam para o contador do futuro
engine, inclusive para representar 256. O TB verifica os dois casos que
virariam `1`, além de 0, 1, 256 e 257. O teste detectou a variante de RTL
com a comparação truncada.

### 16. O módulo implementa os seis modos AES?

Nesta etapa o banco valida `MODE` e copia o código aceito para o snapshot.
Os códigos 0 a 5 representam, na ordem, ECB, CBC, PCBC, CFB, OFB e CTR. Os
códigos 6 e 7 geram `ERROR` e bloqueiam o despacho. O TB verifica a
codificação e a rejeição. O processamento dos blocos, incluindo encadeamento
e acesso à RAM, fica no futuro engine, com P15–P17 ainda abertas.

### 17. Por que START é comando e não um bit armazenado em nível alto?

Se START permanecesse alto no banco e fosse ligado diretamente ao core,
ele poderia iniciar outra operação sempre que BUSY voltasse a zero. Aqui
uma escrita com START=1 é interpretada uma vez na aplicação daquele frame.
Se válida, cria um snapshot valid/ready; START lê zero. O futuro consumidor
gera o pulso local ao consumir o snapshot. Sob backpressure, valid permanece
alto, mas só um handshake é permitido por comando. O TB conta esses consumos
e verifica que comandos ocupados não enfileiram uma segunda operação.

### 18. Qual a diferença entre o DONE do core da Semana 4 e o status SPI?

`done_o` dura um ciclo do core. Entre duas consultas SPI podem passar muitos
ciclos, então `AES_STATUS.DONE` guarda a indicação de conclusão. Ele volta a
zero no reset ou quando um novo START válido é aceito. O banco atualiza
DONE e ERROR a partir do snapshot de status. O TB lê DONE mais de uma vez
e confirma que até um START inválido preserva o valor anterior.

### 19. Quais políticas de erro já são requisito e quais são provisórias?

Modo reservado ou `NUM_BLOCKS` fora de 1 a 256 deve gerar ERROR e impedir o
despacho. As regras abaixo são provisórias (D24, pendências P24/P25):

- ERROR persiste até reset ou START válido. Um START inválido preserva DONE
  e a contagem anterior.
- O banco sinaliza rejeição internamente para escrita em registrador de
  leitura, `RSV` diferente de zero ou endereço inválido. START durante BUSY
  é descartado sem entrar em fila.
- O banco ignora os bits reservados dos controles na escrita e devolve zero
  para eles na leitura.

### 20. O que é CDC e onde ele aparece nesta etapa?

CDC é a passagem de dados entre domínios de clock. Aqui, o receptor usa o
SCLK do mestre e o banco usa `clk`. A relação de fase entre eles é
desconhecida, e SCLK pode parar entre frames. O comando cruza de SCLK para
`clk` e a resposta faz o caminho inverso. O adaptador também transporta
configuração e status entre `clk` e o futuro `sys_clk`. Em cada direção,
os sinais de controle passam por sincronizadores enquanto o dado fica
retido para a captura de uma só vez.

### 21. Por que dois flip-flops não bastam para um barramento multibit?

Ao passar de `0x00FF` para `0x0100`, caminhos com atrasos diferentes podem
produzir uma palavra intermediária que a origem nunca enviou. Dois
flip-flops por bit reduziriam o risco de propagação da metastabilidade,
mas cada bit ainda poderia ser capturado em um ciclo diferente. A mailbox
registra o vetor e alterna `req` na mesma borda. O destino sincroniza `req`,
espera um ciclo de guarda e captura o vetor, que a origem retém até `ack`.
A implementação física precisa de restrições de atraso e skew que garantam
a chegada do vetor dentro dessa janela.

### 22. Como funciona o handshake por toggle da mailbox?

1. Com `req=ack=0`, a origem tem um slot livre. Na borda em que `valid && ready`,
   ela grava o dado em `hold_q` e alterna `req` para 1.
2. O destino sincroniza `req` com dois flip-flops, detecta a diferença,
   espera um ciclo de guarda e captura o vetor. `valid` fica alto até o consumo.
3. No consumo, `ack` passa a 1. Depois de dois flip-flops na volta, a origem
   vê `req=ack` novamente e libera o slot.

Na próxima operação, `req` vai para 0. O novo valor fica estável mesmo que
um dos clocks pare antes de concluir o handshake.

### 23. Por que um toggle sem ack pode perder comandos?

Imagine duas mudanças, `0 → 1 → 0`, entre bordas do clock de destino. O
destino pode observar `0` nas duas bordas e perder os dois eventos. No SPI,
o `ack` sincronizado limita a origem a um frame pendente. O TB pausa `clk`,
envia dois frames completos e retoma o clock. A primeira escrita precisa
chegar intacta e a segunda deve gerar overrun.

### 24. Qual é a política de backpressure e qual seu limite?

A mailbox interna oferece `ready`. O produtor mantém `valid` e o dado até
a aceitação. Na interface SPI, o mestre segue o intervalo de CS alto de D22
e envia os frames sem sinal de retorno de capacidade. Se o slot ainda está
ocupado na 40ª amostra, o periférico descarta o novo frame e mantém ativa
a indicação interna de overrun. A capacidade e a forma de sinalizar o erro
continuam em discussão em P14/P22.

### 25. Por que a implementação pede um intervalo com CS alto?

`clk` precisa observar CS alto para fechar o frame. A margem provisória de
12 ciclos ativos de `clk` cobre a sincronização, a guarda, três observações
de CS em nível alto e a aplicação do comando pelo banco. O TB usa esse
intervalo em 24 frames consecutivos. Enquanto `clk` está parado, a lógica
de qualificação fica parada também. O intervalo definitivo depende de
P14/P22.

### 26. Como o projeto evita operações duplicadas?

O destino emite `frame_valid` por um ciclo ao confirmar um frame íntegro.
O `ack` encerra a transferência, e cada START aceito gera um snapshot que é
consumido uma vez em `valid && ready`. O TB confirma um único consumo mesmo
quando mantém `ready` baixo, altera o banco e tenta outro START durante
BUSY. Se o software enviar dois frames idênticos quando o sistema está
ocioso, o banco os trata como dois comandos distintos.

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

Se `req` já mudou, `clk` pode capturar o vetor retido enquanto `sys_clk`
está parado. No TB, o consumidor em `clk` recebe status nessa condição.
O produtor só vê `status_ready` voltar quando `sys_clk` retoma e sincroniza
o `ack`. Para desligar a PLL com segurança, o futuro controlador deve
tratar essa etapa de confirmação na sequência de desligamento.

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

O banco reinicializa em `clk` e coloca `PLL_ENABLE=1` pela política
provisória. Para liberar a parte serial, o mestre fornece duas subidas de
SCLK com CS alto antes de selecionar o primeiro frame útil. O TB aplica
reset com os clocks parados e reproduz essa sequência. Selecionar antes
dessas bordas pode deixar parte do primeiro frame sob reset. A sequência
definitiva do mestre continua em P21.

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

O scoreboard SPI calcula as palavras esperadas a partir dos estímulos e
compara tanto o readback quanto o snapshot de configuração. O TB do
adaptador registra o esperado em duas filas independentes e compara
conteúdo e ordem no consumo. As sondas internas servem para depuração e
para alinhar eventos simultâneos. Quatro falhas deliberadas do RTL, entre
elas a troca de palavras de KEY, foram detectadas pelos testes.

### 35. O que lint e síntese provaram, e quais problemas reais encontraram?

O lint verificou larguras e uso de sinais, incluindo um bit sem uso e uma
constante larga demais no TB. Na síntese, o frontend slang rejeitou um
processo com dois controles assíncronos. O RTL final combina esses controles
em uma única rede de reset para o enquadramento SPI. A revisão passou em
Verilator `-Wall` sem supressões, Icarus e Yosys. As cinco sínteses genéricas
passaram no `check -assert`, sem latches nas estatísticas. A avaliação de
timing e CDC em hardware depende das análises descritas na pergunta 36.

### 36. O teste a 25 MHz e a síntese comprovam operação do MiniSoC a 2 GHz?

O período de 40 ns no TB verifica o comportamento funcional do SPI com
SCLK ideal a 25 MHz. A síntese do Yosys gera uma rede de células genéricas.
Para avaliar a meta de 2 GHz, é preciso escolher a tecnologia ou o FPGA
alvo, implementar o circuito e rodar STA com as
restrições de clocks e de I/O. A etapa física inclui análise de
CDC/RDC/MTBF e permanece aberta em P27.

### 37. Quais decisões o instrutor ainda precisa confirmar?

- **SPI (P14, P22)** — posição e primeiro bit em MISO, dummy, NOP,
  leituras consecutivas, capacidade, intervalo e overrun.
- **Reset e PLL (P20, P21)** — sequência de reset, relock e preparação do
  mestre quando SCLK está parado.
- **Status e controle (P23 a P25)** — publicação de progresso e conclusão,
  valores de reset, VERSION, bits reservados, ERROR e concorrência.

Os testes usam os valores provisórios definidos em D21–D24. Também seguem
abertas P15–P19, P26 e P27, referentes aos modos, à memória e à etapa física.

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

Pela regra provisória D24, se START chega no mesmo ciclo que a conclusão de
uma operação ocupada, o banco registra a conclusão e rejeita START. No TB,
essa sequência produz `DONE=1` e `BLOCKS_DONE=256`, com a quantidade de
snapshots de configuração consumidos igual à anterior. P25 trata da
prioridade definitiva.

### 40. Qual é a situação objetiva da entrega?

O periférico SPI, o banco de registradores e o adaptador CDC passaram na
regressão e na síntese genérica. Os testes AES anteriores também passaram.
O protocolo detalhado segue as regras provisórias D21–D24. Ficam pendentes
a integração com AES, PLL e RAM, as verificações físicas e o aceite do
instrutor. Os resultados e o estado de cada critério estão no
[relatório da Semana 5](semana_05.md).
