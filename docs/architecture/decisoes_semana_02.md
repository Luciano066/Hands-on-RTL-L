# Registro de decisões — Semana 2

Data: 09/10/2026. Referência de contrato: [arquitetura v1.0](arquitetura_v1.0.md). Todos os ADRs são **decisões arquiteturais provisórias para defesa**, sem aprovação atribuída ao instrutor. P01–P13 referem-se às [pendências originais](../spec/pendencias.md). AES-128 e somente cifragem são hipóteses funcionais; SPI modo 0 é baseline provisório; reset ativo baixo e expansão adiantada são decisões provisórias; 16 + 4 S-boxes são hipótese arquitetural a validar por síntese. Nenhuma dessas seis escolhas é requisito oficial confirmado.

## D01 — Iterativa versus desenrolada

**DECISÃO:** organização do núcleo de cifragem.

**CONTEXTO:** não há meta de throughput ou frequência; o curso prioriza entendimento, RTL verificável e futura avaliação de consumo (P04/P07/P11).

**ALTERNATIVAS:** serialização por byte/palavra; uma rodada por ciclo; duas rodadas por iteração; todas as rodadas replicadas com ou sem pipeline.

**ESCOLHA:** datapath iterativo de 128 bits, uma unidade de rodada reutilizada e um bloco em andamento.

**JUSTIFICATIVA:** controle e comparação de estados intermediários simples, menos replicação que desenrolamento completo, fronteiras claras para enables. SPI comandado por registradores não exige uma fila de blocos por ciclo.

**TRADE-OFFS:** menor vazão do que um pipeline abastecido; 16 substituições paralelas no State ainda custam área. Não se afirma menor energia sem medir. Uma rodada e a expansão paralela precisam fechar timing.

**IMPACTO FUTURO:** se metas exigirem serializar ou criar pipeline, revisar ciclos, S-boxes, handshake e scoreboard. O contrato provisório distingue 11 ciclos de cálculo E0→E11, publicação de done/data_out após E11, captura pelo adaptador em E12 e quatro estados da FSM. O intervalo mínimo de iniciação isolada é 12 períodos, não a latência do banco SPI.

**STATUS:** baseline proposta; depende de requisitos físicos/funcionais e defesa. Não implementada.

## D02 — AES-128 como baseline e operação suportada

**DECISÃO:** tamanho inicial da chave e escopo criptográfico.

**CONTEXTO:** a Semana 1 usou AES-128 apenas didaticamente; P01/P02/P13 continuam sem especificação oficial.

**ALTERNATIVAS:** AES-128, AES-192, AES-256 ou núcleo multivariante; cifragem e/ou decifragem; modos externos.

**ESCOLHA:** baseline provisório AES-128; hipótese funcional de somente cifragem de um bloco por operação, pendente de confirmação; nenhum modo de mensagens adicionado.

**JUSTIFICATIVA:** permite definir interfaces e escalonamento com o menor escopo inicialmente solicitado. Não é uma conclusão de que outras variantes sejam desnecessárias para o curso.

**TRADE-OFFS:** limita funcionalidade e pode exigir revisão posterior. AES-192/256 alteram expansão e número de rodadas, não apenas uma constante de contador.

**IMPACTO FUTURO:** confirmar antes de congelar o núcleo; decifragem pode exigir chaves em ordem inversa e funções adicionais.

**STATUS:** hipótese funcional pendente. **AES-128 é adotado como baseline arquitetural provisório para permitir o desenvolvimento, sujeito à confirmação da especificação funcional do instrutor.**

## D03 — Largura e empacotamento do banco

**DECISÃO:** granularidade de acesso e ordem de bits/bytes.

**CONTEXTO:** SPI é serial, mas núcleo recebe dois operandos completos de 128 bits (P05).

**ALTERNATIVAS:** bytes, palavras de 16/32 bits, comandos de 128 bits ou FIFO de bytes.

**ESCOLHA:** palavras de 32 bits completas, quatro palavras por vetor; endereço em bytes alinhado a quatro; palavra 0 corresponde a bits 127:96. Byte 0 é bits 127:120; transmissão MSB primeiro.

**JUSTIFICATIVA:** quatro comandos por operando, associação direta com colunas, máscara de quatro bits e ausência de byte-enable.

**TRADE-OFFS:** não permite alterar um byte isoladamente; frame mais longo precisa de staging e abort seguro. Ordem precisa ser explícita para software e testes.

**IMPACTO FUTURO:** preservar conversões na verificação e em eventual driver. Mudança de granularidade altera protocolo, não o algoritmo.

**STATUS:** decisão proposta para P05, sujeita à compatibilidade do mestre.

## D04 — Key Expansion durante o cálculo

**DECISÃO:** gerar ou armazenar todas as round keys.

**CONTEXTO:** o núcleo iterativo precisa de uma chave por rodada; reutilização de chave e decifragem não estão especificadas (P08).

**ALTERNATIVAS:** pré-expandir K0..K10 em 1408 bits; geração a cada rodada; cache híbrido.

**ESCOLHA:** registrador de round key de 128 bits, geração adiantada: K1 durante INIT e K(r+1) durante a rodada r, para r de 1 a 9.

**JUSTIFICATIVA:** evita banco de todas as chaves e não encadeia a expansão com o caminho State→AddRoundKey corrente. Quatro S-boxes próprias permitem o paralelismo.

**TRADE-OFFS:** recalcula por bloco; mais atividade que um cache em uso intensivo da mesma chave. As cópias K0 no banco/adaptador continuam existindo; economia não é 1408−128 bits no sistema inteiro.

**IMPACTO FUTURO:** medir energia com chave fixa e variável; rever para decifragem, ROM síncrona ou exigência de frequência maior.

**STATUS:** decisão arquitetural provisória, pendente de confirmação do instrutor e validação por síntese/STA; planejamento de implementação na Semana 4 condicionado ao escopo aprovado.

## D05 — Organização de S-box

**DECISÃO:** paralelismo e realização inicial da substituição.

**CONTEXTO:** uma rodada por ciclo demanda dezesseis substituições do State e até quatro da expansão simultaneamente (P10).

**ALTERNATIVAS:** tabela combinacional, ROM/LUT, lógica algébrica, compartilhamento temporal, diferentes números de instâncias.

**ESCOLHA:** hipótese arquitetural de 16 S-boxes lógicas no State e 4 na expansão; preferência provisória por tabela combinacional completa.

**JUSTIFICATIVA:** 16 instâncias atendem os 16 bytes independentes do State em paralelo; quatro adicionais atendem os quatro bytes de SubWord sem disputar o datapath. É coerente com uma rodada/ciclo e chave adiantada, se ambos os caminhos fecharem timing. A tabela facilita conferir as 256 entradas.

**TRADE-OFFS:** vinte funções replicadas custam área, capacitância e atividade potencial, sem valor físico conhecido. O período depende do pior caminho de rodada ou expansão e potência inclui glitches. Case não garante ROM; ROM síncrona muda latência/portas. Compartilhar quatro unidades exige pelo menos quatro ciclos de consulta para State e outro grupo para SubWord; compartilhar uma exige 16 + 4 consultas nas rodadas 1–9. Controle pode acrescentar ciclos, aumentando intervalo de iniciação e reduzindo throughput na mesma frequência.

**IMPACTO FUTURO:** comparar síntese e equivalência de alternativas na tecnologia oficial; não confundir função matemática com mapeamento físico.

**STATUS:** hipótese arquitetural provisória a validar por síntese, STA e análise de atividade na tecnologia-alvo, sujeita à confirmação do instrutor. Não é solução comprovadamente ótima; S-box definitiva ainda não escrita.

## D06 — Divisão de clocks

**DECISÃO:** SCLK no front-end e clk_sys no processamento.

**CONTEXTO:** o mestre pode parar SCLK e não foi dada relação com clock de sistema (P04/P09).

**ALTERNATIVAS:** tudo em SCLK; sobreamostragem em clk_sys; dois domínios assíncronos.

**ESCOLHA:** banco/parser na subida de SCLK, MISO na descida; adaptador e AES na subida de clk_sys.

**JUSTIFICATIVA:** AES progride com SCLK parado e o protocolo SPI não exige uma razão de oversampling inventada.

**TRADE-OFFS:** exige CDC e reset por domínio/fase; MISO impõe timing de meia fase. Duas fases do mesmo SCLK são relacionadas, não clocks independentes.

**IMPACTO FUTURO:** criar restrições de clocks/I/O e avaliar gating sem bloquear a recepção de requisições.

**STATUS:** divisão proposta; períodos, duty cycle e limites de pinos pendentes.

## D07 — Reset

**DECISÃO:** polaridade, assert/deassert e recuperação.

**CONTEXTO:** reset não foi fixado na Semana 1, e SCLK pode parar (P06).

**ALTERNATIVAS:** síncrono; assíncrono direto; reset comum com deassert sincronizado por domínio; resets separados com recuperação coordenada; polaridade alta ou baixa. Exigir SCLK externo na partida é uma condição de integração, não uma forma de reset que dispense clocks.

**ESCOLHA:** decisão provisória de rst_n ativo baixo comum ao IP, assert assíncrono e deassert por dois FF em cada domínio/fase. Propor quatro períodos de inicialização SCLK com CS_N alto e quatro ciclos de clk_sys após liberação, ainda dependente da capacidade do mestre e da aprovação do instrutor.

**JUSTIFICATIVA:** zera mesmo sem clock, com retomada controlada; polaridade explícita para integração.

**TRADE-OFFS:** com SCLK parado, SPI pode permanecer em reset indefinidamente: risco R05 alto, ainda aberto. Resets separados não criam bordas e podem desalinhar o handshake. Largura de pulso e recovery/removal dependem da tecnologia. CS_N apenas reinicia framing; não reseta a transação.

**IMPACTO FUTURO:** reset independente/power gating requer protocolo adicional de recuperação e análise de RDC.

**STATUS:** decisão arquitetural provisória, não requisito oficial. Pergunta obrigatória ao professor: quem gera SCLK de inicialização com CS_N alto e qual alternativa/recuperação adotar se isso ou reset comum não forem possíveis?

## D08 — CDC com banco estável e handshake

**DECISÃO:** transporte atômico de comando e resultado.

**CONTEXTO:** chave/entrada chegam em palavras, clocks não são relacionados e não há demanda documentada por fila (P09).

**ALTERNATIVAS:** pulso alongado, toggle com ack, handshake de níveis, FIFO assíncrona, shadow registers sem ou com controle.

**ESCOLHA:** quatro fases `(req,ack_done): 00→10→11→01→00`, com banco congelado e ACK retardado até a conclusão. req passa por dois FF em clk_sys; ack_done por dois FF em SCLK. KEY/plaintext de 256 bits vão do SPI ao adaptador; ciphertext de 128 bits retorna de result_hold ao SPI, sem sincronização bit a bit. A seção 7.2 da arquitetura enumera as onze etapas, incluindo liberação somente após ACK baixo sincronizado.

**JUSTIFICATIVA:** requisição e conclusão persistem sem SCLK; um slot evita sobreposição e duplicação. Dados retidos permitem captura coerente; dois FF independentes por bit poderiam misturar épocas. DONE é gerado localmente pela captura do retorno, BUSY é local à transação; STATUS inteiro não cruza domínios.

**TRADE-OFFS:** BUSY dura além do cálculo; throughput inclui ida e volta. Ack não confirma captura antecipada, confirma resultado. Captura estável precisa de orçamento físico de atraso/skew e não pode ser justificada só por dois FF.

**IMPACTO FUTURO:** propriedades digitais de estabilidade e unicidade, teste de clocks pausados, análise CDC/STA/MTBF; FIFO apenas se demanda justificar.

**STATUS:** protocolo proposto; segurança física e implementação ainda não verificadas.

## D09 — START, BUSY, DONE e erros

**DECISÃO:** semântica de comando e conclusão.

**CONTEXTO:** mestre precisa distinguir aceitação, cálculo, resultado e disponibilidade para próximo comando.

**ALTERNATIVAS:** fila de START, restart, ignorar sem diagnóstico ou rejeitar com erro; pulso interno versus status persistente. Para limpar DONE: novo START aceito, write-1-to-clear explícito ou leitura com efeito colateral.

**ESCOLHA:** baseline provisório em que START admissível reserva o slot; BUSY cobre todo handshake; START ocupado/incompleto é rejeitado com ERROR sticky. `done` interno é pulso clk_sys após E11; `DONE` do banco é sticky em SCLK e nasce com DATA_OUT capturado. Limpa por novo START aceito, reset ou write-1-to-clear via comando CONTROL.CLR_DONE; STATUS permanece RO e leitura não limpa.

**JUSTIFICATIVA:** limpeza no próximo START separa operações sem comando adicional; CLR_DONE permite reconhecer sem iniciar outra operação. Limpeza por leitura foi rejeitada para não consumir notificação em polling/diagnóstico. Comando ocupado não corrompe operação e não há fila implícita.

**TRADE-OFFS:** BUSY=1/DONE=1 é possível durante fechamento; ERROR não fornece código detalhado. DATA_OUT antes de DONE pode conter dado antigo.

**IMPACTO FUTURO:** driver e testes devem aguardar slot livre; resultado ganha de CLR_DONE concorrente, novo erro ganha de CLR_ERROR. Elegibilidade usa estado anterior à borda.

**STATUS:** contrato proposto para revisão com verificador/professor.

## D10 — Organização do mapa

**DECISÃO:** disposição de controle e operandos no endereço de oito bits.

**CONTEXTO:** precisa ser simples de decodificar e fácil de explicar; exemplo fornecido pelo estudante não era mapa obrigatório.

**ALTERNATIVAS:** sequência compacta de bytes; palavras em endereços consecutivos; janelas alinhadas por operando.

**ESCOLHA:** STATUS 0x00, CONTROL 0x04, VALID_MASK 0x08; KEY 0x20–0x2C, DATA_IN 0x30–0x3C, DATA_OUT 0x40–0x4C, em passos de quatro.

**JUSTIFICATIVA:** status acessível primeiro; nibble alto identifica janela e cada janela contém um vetor de 128 bits. Espaços reservados não possuem side effects.

**TRADE-OFFS:** deixa endereços livres; decodificação deve rejeitar desalinhados/reservados sem aliases. KEY permite readback por conveniência acadêmica, a confirmar frente ao escopo de segurança.

**IMPACTO FUTURO:** extensões precisam de versão/documentação; alterar mapa depois exige atualizar mestre e verificações.

**STATUS:** proposta própria, sujeita à aprovação de P05 e requisitos de acesso à chave.

## D11 — Frame SPI mínimo

**DECISÃO:** modo e enquadramento do transporte.

**CONTEXTO:** P03/P05 ainda abertos, sem controlador especificado.

**ALTERNATIVAS:** um dos quatro modos, modo configurável, comandos variáveis, burst ou frame fixo.

**ESCOLHA:** **SPI modo 0 como baseline provisório, não requisito oficial**, MSB primeiro, opcode de oito bits (0x02 escrita / 0x03 leitura), endereço de oito bits e palavra de 32 bits, total 48 clocks por seleção.

**JUSTIFICATIVA:** parser pequeno e comprimento previsível; quatro escritas completam cada operando. Snapshot de leitura no fim do endereço permite resposta sem CDC por palavra.

**TRADE-OFFS:** overhead de 16 bits por palavra e sem burst/CRC; frame incompleto é descartado; clocks além de 48 são ignorados até CS_N subir. Não existe confirmação serial dedicada para cada escrita, usa-se STATUS.

**IMPACTO FUTURO:** validar primeiro bit, CS_N e meia fase de MISO; alterar modo ou usar bursts exige nova cobertura.

**STATUS:** baseline provisório pendente de confirmação do instrutor sobre modo e mestre (P03/P05). Outro modo exige revisão das bordas, primeiro bit e testes; SPI funcional permanece para Semana 5.

## D12 — Completude, bloqueio e reutilização

**DECISÃO:** impedir uso de operandos parciais e preservar transferência em andamento.

**CONTEXTO:** quatro escritas independentes podem deixar mistura de dados novos/antigos; uma máscara permanentemente válida após a primeira chave não detectaria substituição parcial.

**ALTERNATIVAS:** confiar no software; máscara cumulativa desde reset; comando explícito BEGIN/COMMIT; congelamento com máscaras por conjunto.

**ESCOLHA:** `KEY_VALID_MASK[3:0]` e `DATA_IN_VALID_MASK[3:0]` iniciam em zero; escritas completas válidas setam o bit do índice. A primeira escrita após máscara completa inicia novo conjunto, limpando demais bits. START só aceita com ambas em 1111 e BUSY=0; consome validade de DATA_IN e preserva KEY. BUSY bloqueia escritas a ambos. A seção 12.3 da arquitetura especifica a tabela de eventos e o exemplo de substituição.

**JUSTIFICATIVA:** impede início após substituir só parte da chave sem acrescentar novos comandos. Reutiliza chave completa entre blocos e obriga plaintext completo por operação.

**TRADE-OFFS:** patch parcial não é suportado; mesmo a reescrita de uma palavra igual inicia substituição se o grupo estava completo. Não se pode preparar o próximo bloco enquanto BUSY=1.

**IMPACTO FUTURO:** testar todas as máscaras e ordens de escrita; adicionar duplo buffer apenas se houver necessidade de sobreposição.

**STATUS:** contrato proposto, a revisar com quem escreverá o mestre e o testbench.
