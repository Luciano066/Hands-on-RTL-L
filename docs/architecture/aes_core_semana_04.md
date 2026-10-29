# Contrato interno da Semana 4 — expansão e primitiva sequencial

Data: 29/10/2026. **D20: escolhas locais implementadas e testadas, sem aceite
do instrutor.** Complementa a [arquitetura v1.1](arquitetura_v1.1.md), cujo
arquivo e contratos permanecem preservados. P14–P27 não foram encerradas.

`minisoc_aes_top` continua reservado ao engine com modos e porta de memória.
O novo `minisoc_aes_core` é um auxiliar interno para a primitiva de um bloco;
não ocupa o lugar de `minisoc_top` nem acrescenta portas externas ao MiniSoC.
O datapath e seu package da Semana 3 são reutilizados sem alteração.

## Expansão: minisoc_aes_key_exp

| Porta | Direção/largura | Contrato local |
|---|---|---|
| clk | Entrada 1 | Clock local do AES, borda de subida |
| rst_n | Entrada 1 | Assert assíncrono baixo; integração deverá sincronizar deassert |
| start_i | Entrada 1 | Amostrado quando busy_o=0 |
| key_i | Entrada 128 | Capturada junto com START aceito |
| round_i | Entrada 4 | Índice de leitura 0..10, independente da geração |
| round_key_o | Saída 128 | Chave normal K[round_i] se valid_o=1; zero se inválida ou índice 11..15 |
| busy_o | Saída 1 | Geração em andamento |
| done_o | Saída 1 | Pulso de um ciclo ao completar K10 |
| valid_o | Saída 1 | Banco completo disponível até novo START aceito/reset |

Pré-expansão conforme D18: K0 é armazenada em E0, K1..K10 em E1..E10.
RotWord/SubWord/Rcon são aplicados à última palavra; as quatro palavras da
nova chave são formadas por XOR encadeado. Rcon começa em 01 e avança por
xtime. Cada posição contém 128 bits, totalizando 1408 bits lógicos de chaves.
Não se geram chaves transformadas para EQINVCIPHER.

Leitura combinacional pelo índice permite ordem K0..K10 e K10..K0 sem
recalcular chaves. O banco só fica acessível quando completo. Em novo START,
valid_o baixa imediatamente após a captura; não há cache entre operações.
START durante BUSY, inclusive na borda que termina K10, é ignorado sem fila.
Se START continuar alto até a próxima borda ociosa, será uma nova aceitação.

Reset limpa controle, chave corrente e validade; o banco de onze chaves não
recebe reset. Leituras permanecem mascaradas até todas as posições serem
sobrescritas por uma expansão nova. Isso não promete zeroização física.

## Núcleo: minisoc_aes_core

| Porta | Direção/largura | Contrato local |
|---|---|---|
| clk/rst_n | Entradas 1 cada | Mesmo domínio/reset local da expansão |
| start_i | Entrada 1 | Pedido amostrado somente em IDLE |
| decrypt_i | Entrada 1 | 0 cipher; 1 INVCIPHER, capturado na aceitação |
| key_i/data_i | Entradas 128 cada | Chave capturada pela expansão e bloco pelo State na mesma borda |
| busy_o | Saída 1 | 1 enquanto FSM não está em IDLE |
| done_o | Saída 1 | Pulso de um ciclo junto com publicação do resultado |
| data_o | Saída 128 | Retém último resultado até outra conclusão ou reset |

Qualquer chave/bloco de 128 bits é válido. Não há porta de erro ou modo neste
auxiliar. START ocupado é ignorado, inclusive na borda de conclusão;
mudanças em key_i/data_i/decrypt_i após aceitação não afetam a operação.
Essa política local não resolve a política de AES_CONTROL/ERROR da P25.
O chamador deve pulsar START; se mantiver o nível alto até IDLE, há nova aceitação.

FSM: IDLE → WAIT_KEYS → ROUND → FINAL_ROUND → IDLE.
WAIT_KEYS espera o banco completo e realiza o AddRoundKey inicial na saída.
ROUND é reutilizado nove vezes; FINAL_ROUND publica o resultado novo do
datapath e não uma cópia do State da rodada anterior.

| Borda relativa à aceitação | Ação capturada |
|---|---|
| E0 | Bloco/direção e K0 capturados; BUSY sobe |
| E1..E10 | Expansão gera K1..K10; State e saída publicada são retidos |
| E11 | Núcleo observa conclusão da expansão e captura adição inicial com K0/K10 |
| E12..E20 | Nove rodadas completas com K1..K9 ou K9..K1 |
| E21 | Rodada final sem mistura, com K10/K0; data_o novo, DONE=1 e BUSY=0 |
| E22 | Consumidor sequencial pode capturar resultado; DONE limpa; novo START pode ser aceito |

Latência local: 21 períodos clk, contados E0→E21, nos dois sentidos.
Intervalo mínimo entre aceitações: 22 períodos, com reexpansão por operação.
O consumidor no mesmo clock amostra a publicação na borda seguinte (E22).
Esses números não incluem RAM, modos, CDC, PLL ou SPI e não são frequência física.

Reset assíncrono aborta a operação e zera State, direção, contador, saída e
DONE; BUSY volta a zero. O banco de chaves perde validade. Deassert não foi
sincronizado dentro deste auxiliar: cabe ao integrador fornecer reset local
correto, sem considerar P20/P21 resolvidas. Não há clock gating.

O [relatório da Semana 4](../reports/semana_04.md) registra vetores, testes,
síntese genérica, limites e questões ainda pendentes.
