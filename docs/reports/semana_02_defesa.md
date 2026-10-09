# Defesa técnica — Semana 2

Base: [arquitetura v1.0](../architecture/arquitetura_v1.0.md) e [12 ADRs](../architecture/decisoes_semana_02.md). **Proposta ainda sem aceite do instrutor.** As respostas distinguem escolha arquitetural, requisito e evidência executada.

As respostas operacionais são condicionais à baseline provisória: AES-128 e somente cifragem são hipóteses funcionais; SPI modo 0 é baseline provisório; reset ativo baixo e expansão adiantada são decisões arquiteturais provisórias; 16 + 4 S-boxes são hipótese a validar por síntese. Nenhuma dessas escolhas é requisito oficial confirmado. A seção 3 da arquitetura é a referência de status para este roteiro de **100 perguntas**.

## Roteiro curto de apresentação — aproximadamente cinco minutos

1. **Escopo, 30 s:** “A Semana 1 validou o ambiente com uma XOR. Nesta semana defini os contratos do acelerador. AES-128 e somente cifragem são hipóteses para confirmação, não requisitos oficiais presumidos.”
2. **Blocos, 45 s:** mostrar mestre → SPI → banco em SCLK → handshake CDC → adaptador e AES em clk_sys, e retorno atômico do resultado.
3. **Microarquitetura, 60 s:** explicar reuso de uma rodada, registrador State, hipótese de 16 S-boxes de dados + 4 de chave, expansão adiantada provisória e bypass final.
4. **Ciclos, 45 s:** apontar E0 aceitação local/carga, E1 adição inicial, E2–E10 nove rodadas, E11 final/saída/done, E12 captura pelo adaptador. Distinguir onze ciclos de cálculo, doze bordas E0–E11 e quatro estados de FSM; não atribuir essa latência a STATUS.DONE.
5. **Interface/CDC/reset, 90 s:** mostrar máscaras, done/DONE/BUSY e quatro fases. SPI modo 0 e reset baixo são provisórios. Parar SCLK retém resultado, mas pode impedir liberação de reset; capacidade do mestre fornecer clocks é pergunta obrigatória.
6. **Limites e aceite, 30 s:** explicitar frequências/tecnologia pendentes, CDC físico ainda não demonstrado, revisão do parceiro e perguntas ao professor.

Não apresentar stub ou simulação XOR como demonstração de AES. As tabelas e diagramas são o objeto desta defesa.

## Perguntas e respostas — fundamentos e escopo

1. **Qual é a entrega desta semana?** Arquitetura e microarquitetura: blocos, interfaces, clocks/reset, CDC, mapa e protocolo, com decisões justificadas e preparação da defesa.

2. **O que já existe em RTL?** Somente o smoke XOR da Semana 1. Não foram acrescentadas transformações AES nem SPI funcional.

3. **O FIPS obriga uma arquitetura iterativa?** Não. Ele define a transformação e o resultado; a organização em hardware é uma escolha de engenharia.

4. **AES-128 já é requisito oficial?** Não. É baseline provisório sujeito à confirmação funcional do instrutor; antes era apenas referência didática.

5. **Qual o tamanho do bloco e da chave nesta proposta?** Ambos têm 128 bits. O sufixo AES-128 identifica o tamanho da chave; outras variantes também processam blocos de 128 bits.

6. **Há decifragem?** Não na baseline proposta. Se for exigida, serão revistos datapath, controle e disponibilidade das round keys.

7. **Foi escolhido um modo de operação como CBC ou GCM?** Não. O IP proposto calcula a primitiva de cifragem de um bloco; modos e autenticação são escopo ainda a confirmar.

8. **O que torna a Semana 2 concluída?** A aprovação da arquitetura pelo instrutor, após defesa, e o atendimento das entregas incluindo a revisão/apresentação ao verificador. Arquivos prontos não comprovam essas atividades.

## Escolha de arquitetura e recursos

9. **Por que arquitetura iterativa?** Reutiliza uma unidade de rodada, facilita controle e verificação por estados, e não há meta de vazão que justifique replicar todas as rodadas.

10. **Por que não desenrolar as dez rodadas?** Isso aumenta recursos e distribuição de chaves. Sem pipeline o caminho fica longo; com pipeline a vazão só é aproveitada se a entrada o abastecer.

11. **Qual seria o impacto em área?** Replicaria grande parte da lógica de rodada e possivelmente registradores de pipeline. A área total não pode ser afirmada como exatamente dez vezes, pois controle e otimizações diferem.

12. **O que significa parcialmente desenrolada?** Replicar parte do trabalho, por exemplo duas rodadas encadeadas por iteração. Diminui iterações, mas pode aumentar o período do clock e a necessidade de chaves simultâneas.

13. **Desenrolar aumenta sempre a frequência?** Não. Encadear mais lógica sem registradores tende a alongar o caminho crítico. Pipeline muda esse equilíbrio ao custo de registradores e controle.

14. **Uma rodada por ciclo significa uma S-box?** Não. Nesta proposta, os dezesseis bytes do State são substituídos em paralelo, e a expansão tem quatro substituições próprias.

15. **Uma arquitetura serializada é pior?** Não necessariamente. Pode atender metas menores de área, com mais ciclos e controle. Não foi escolhida porque queremos uma baseline simples de uma rodada por ciclo.

16. **O SPI será necessariamente o gargalo?** Não se pode concluir sem frequências. O protocolo custa 624 clocks SCLK por operação com chave nova, fora polling; isso deve ser comparado ao tempo de núcleo e CDC.

17. **Qual a diferença entre latência e throughput?** Latência é tempo de um pedido até seu resultado. Throughput é quantidade de resultados por tempo em regime, dependente do intervalo entre novas operações.

18. **Menor área garante menor consumo?** Não. Atividade, capacitância, clock, tensão e tempo ativo também importam. Precisamos comparar potência e energia por bloco em cenários equivalentes.

## Datapath, State e ciclos

19. **Por que o State precisa de registrador?** Para manter o resultado de uma iteração enquanto a mesma lógica combinacional é reutilizada na seguinte e delimitar o caminho entre bordas.

20. **Como os bytes entram no State?** Byte i vem de bits `[127-8*i -: 8]`; a posição é `s[r,c]=byte[r+4*c]`, preenchendo colunas.

21. **O que vale DATA_IN0 no exemplo 00112233...?** É 0x00112233 e ocupa bits 127:96. DATA_IN3 contém os últimos quatro bytes, em bits 31:0.

22. **ShiftRows precisa de muitos registradores?** Na proposta paralela, é principalmente permutação de conexões. O registro de fronteira é o State; a síntese e o roteamento determinarão custos físicos.

23. **Onde fica AddRoundKey?** No final do caminho de rodada, após MixColumns ou seu bypass. Na inicialização, o mux seleciona State carregado e K0 para a adição inicial.

24. **Como a última rodada é tratada?** O contador/FSM seleciona SubBytes, ShiftRows e AddRoundKey com K10, desviando de MixColumns e desabilitando geração de chave seguinte.

25. **Por que omitir MixColumns no final?** Porque essa é a sequência normativa da cifragem AES. Colocá-la muda o resultado esperado.

26. **Quantos ciclos uma operação leva?** Após aceitar start local em E0, há onze ciclos de cálculo e publicação de data_out/done após E11. O adaptador captura em E12. As doze bordas E0–E11 não são doze períodos nem estados; a latência de START SPI até DONE é variável.

27. **Pode explicar cada etapa?** E0 carrega State e K0; E1 faz adição inicial e gera K1; E2–E10 executam rodadas 1–9 e preparam a próxima chave; E11 executa a final e publica a saída.

28. **Por que não há estado LOAD ou DONE separado?** A FSM tem quatro estados: IDLE, INIT, ROUND e FINAL. Carga acontece na aceitação em IDLE; publicação acontece na final. ROUND dura nove ciclos, usando contador, sem nove estados distintos.

29. **Qual o intervalo mínimo entre dois START aceitos no núcleo?** Doze ciclos, E0 e E12. Na E11 o busy anterior ainda era 1; no sistema completo é preciso aguardar também o handshake.

30. **Como obter dez períodos de latência?** Uma alternativa é combinar carga e adição inicial na aceitação. Não é a baseline; mudaria o caminho de entrada e o contrato de teste.

31. **Quando o adaptador consegue amostrar done?** A saída muda após E11; o consumidor sequencial a amostra em E12 junto com data_out. O adaptador publica ack_done em E13, após reter o resultado.

32. **Qual parte será mais crítica em timing?** Candidatas são State→S-box→mistura/XOR→State e round key→S-box/XOR→round key. Sem síntese não podemos escolher definitivamente uma delas.

## Expansão de chave e S-box

33. **Como as round keys são geradas?** A decisão provisória é gerar a próxima em paralelo: K1 em INIT e K(r+1) durante rodadas r=1..9, usando quatro S-boxes próprias. Depende do escopo aprovado e da síntese; não foi demonstrada ótima.

34. **A expansão fica em série com a rodada?** Não nesta proposta: a rodada usa a chave já registrada, e a expansão prepara a seguinte em paralelo. Cada caminho ainda precisa fechar seu timing.

35. **Por que não armazenar todas as round keys?** Onze chaves de 128 bits representam 1408 bits de armazenamento, mais controle. Preferimos primeiro o registrador corrente, pois a reutilização intensa de chave ainda não é um requisito.

36. **Pré-calcular pode consumir menos energia?** Sim, se muitos blocos reutilizarem a mesma chave e a economia de recálculo compensar armazenamento e leitura. Isso depende do perfil e precisa de medição.

37. **Onde a chave original fica preservada?** No banco SPI, enquanto completa e não substituída/resetada. O adaptador captura uma cópia para a operação; o núcleo pode sobrescrever seu registrador de round key.

38. **São apenas 128 bits de chave em todo o IP?** Não. Esse é o registrador corrente do núcleo; existem a chave no banco e a cópia do adaptador, além dos demais dados e controle.

39. **Por que propor vinte S-boxes?** Dezesseis transformam os dezesseis bytes do State em paralelo; quatro atendem SubWord simultaneamente, sem disputa. É hipótese arquitetural a validar por síntese, com custo de área e atividade, não quantidade oficial exigida nem vinte memórias físicas garantidas.

40. **Como reduzir o número de S-boxes?** Compartilhar uma ou quatro unidades, ou pré-expandir chaves. Uma unidade exige dezesseis consultas de State e quatro de SubWord nas rodadas 1–9; quatro unidades precisam de quatro grupos para State e outro para chave. Mais controle/ciclos reduzem throughput na mesma frequência; a latência atual precisa ser revista.

41. **Por que tabela combinacional inicialmente?** É uma forma direta de conferir a função em 256 entradas. A realização física e sua qualidade serão avaliadas na tecnologia escolhida.

42. **Um case vira ROM obrigatoriamente?** Não. Pode virar portas ou LUTs conforme ferramenta e alvo. A disponibilidade de portas e latência não deve ser inferida apenas do estilo do código.

43. **Pode trocar por ROM síncrona sem alterar nada?** Não. A consulta passa a ter latência registrada e pode haver limitação de portas; o escalonamento precisa ser revisto.

44. **Lógica algébrica é sempre menor?** Não. Depende da decomposição e da biblioteca; também precisa de prova de equivalência à S-box e comparação de atraso/atividade.

## Interface, mapa e comandos

45. **Por que existe banco de registradores?** Reúne palavras recebidas serialmente, permite checar completude e expõe controle, estado e resultado retido para o mestre.

46. **Como SPI transfere 128 bits?** Quatro transações de palavras de 32 bits. Cada frame tem opcode de oito bits, endereço de oito bits e 32 bits de payload, totalizando 48 clocks.

47. **Por que dividir em palavras, não bytes?** Reduz o número de cabeçalhos e usa quatro bits de validade por vetor. Em troca, não há escrita parcial por byte.

48. **Por que esses endereços?** STATUS/CONTROL/máscaras estão no início; janelas de 16 bytes em 0x20/0x30/0x40 distinguem chave/entrada/saída e mantêm alinhamento de quatro bytes.

49. **Como evitar iniciar com chave incompleta?** START exige KEY_VALID_MASK e DATA_IN_VALID_MASK em 1111 e BUSY=0. Reset zera; escrita válida seta o bit do índice. A primeira escrita após chave completa reinicia o conjunto com um só bit, impedindo uso de chave parcialmente substituída.

50. **Posso reaproveitar a chave sem reescrevê-la?** Sim. START preserva KEY_READY, mas consome a máscara de DATA_IN, exigindo novo bloco completo.

51. **E se escrever uma palavra da chave igual ao valor anterior?** Ainda inicia um novo conjunto se a máscara estava completa. Validade depende das escritas, não de comparar o conteúdo.

52. **O que acontece se START ocorrer durante BUSY?** O banco rejeita, seta ERROR e não enfileira, reinicia ou modifica a operação. O núcleo isolado ignora start ocupado.

53. **Posso escrever a chave enquanto o AES calcula?** Nesta baseline, não: durante todo BUSY a escrita é ignorada e seta ERROR. Assim o barramento de origem permanece estável para CDC.

54. **Quando DONE é limpo?** Na baseline provisória: reset, novo START aceito ou escrita de 1 em CONTROL.CLR_DONE. É limpeza explícita com efeito write-1-to-clear; STATUS permanece RO. Leitura e START rejeitado não limpam. A chegada do resultado vence clear simultâneo.

55. **DATA_OUT pode mudar antes de DONE?** Para a operação atual, a publicação dos 128 bits e DONE ocorre na mesma borda SPI. Antes disso o banco conserva a saída anterior, sem expor State intermediário.

56. **O que uma leitura antes de DONE retorna?** O último resultado ou zero após reset. É uma leitura permitida, mas não qualifica a conclusão da operação atual.

57. **Posso ler um resultado com BUSY ainda em 1?** Sim, se DONE=1: o resultado já foi capturado e o handshake está fechando. Um novo START ainda precisa aguardar BUSY=0.

58. **As quatro palavras de saída são sempre uma foto atômica em qualquer leitura?** A atualização interna é atômica, mas quatro transações atravessando uma conclusão podem misturar épocas. O mestre lê após DONE e não inicia outra operação até terminar.

59. **Precisa de ready, key_valid e data_valid no núcleo?** Não aqui. !busy indica disponibilidade local e o adaptador só envia operandos completos; as máscaras fazem a validação no banco.

60. **Por que não há error no núcleo AES?** Qualquer chave/bloco de 128 bits é admissível. Erros de comando são detectados no banco; falhas internas e proteção física não foram incluídas no escopo.

## Clocks, reset e CDC

61. **Por que existem dois clocks?** O mestre comanda SCLK; o sistema comanda clk_sys. Mantê-los separados permite terminar AES mesmo que o mestre pare a interface.

62. **O que é metastabilidade?** Uma condição física em que um flip-flop pode demorar a resolver seu estado após amostrar perto de uma transição. Não é corretamente demonstrada por um X de simulação comum.

63. **Por que dois flip-flops não resolvem um barramento multibit?** Cada bit pode chegar/resolver em ciclos diferentes, formando uma palavra que nunca existiu na origem. É necessário garantir coerência por protocolo.

64. **Por que usar handshake?** Ele mantém pedido e confirmação observáveis e impede sobrescrever dados antes da captura, inclusive quando SCLK para.

65. **Quais sinais realmente cruzam por sincronizadores de um bit?** req em direção a clk_sys e ack_done em direção a SCLK. Os dados cruzam como barramentos estáveis sob captura controlada.

66. **Qual é a sequência completa do handshake?** Preparar dados, congelar, subir req, sincronizar req, capturar, executar e subir ack_done, sincronizar ack e capturar retorno, baixar req, observar req baixo, baixar ack, observar ack baixo e liberar. As quatro fases são 00→10→11→01→00; ACK é retardado até o resultado, e liberação espera ACK baixo sincronizado.

67. **Por que ack significa resultado pronto?** Assim um único handshake cobre pedido e resposta com um slot. Confirmação antecipada exigiria outro mecanismo para transportar conclusão e ciphertext.

68. **O que impede executar várias vezes enquanto req permanece alto?** A FSM do adaptador só aceita na fase livre e não rearma antes do retorno completo a zero.

69. **Por que não transmitir start e done como pulsos assíncronos?** Um pulso pode ocorrer inteiro entre bordas do receptor ou durante pausa de SCLK. Os eventos entre domínios são níveis persistentes, e os pulsos só existem localmente.

70. **Toggle seria possível?** Sim, com ack e controle para não emitir outro evento antes de o anterior ser observado. Escolhemos níveis de quatro fases para facilitar explicar estados e retorno a zero.

71. **Por que não uma FIFO assíncrona?** Não precisamos de rajadas com vários blocos em voo. Uma FIFO acrescentaria ponteiros, armazenamento e verificação de cheio/vazio/reset sem necessidade atual.

72. **Basta congelar dados para afirmar CDC seguro?** Não. Precisamos provar estabilidade pelo protocolo e verificar atraso/skew, janela de captura, sincronizadores e MTBF na implementação física.

73. **Por que há uma borda adicional de guarda?** Ela separa detecção do controle sincronizado da captura do barramento. A margem ajuda, mas não substitui a restrição temporal do caminho de dados.

74. **O que acontece se SCLK parar depois de START?** AES pode terminar em clk_sys; resultado e ack ficam retidos. O mestre precisa retomar clocks, por exemplo via polling, para atualizar DONE e fechar BUSY no banco.

75. **Existe latência máxima externa se SCLK puder parar?** Não sem uma hipótese de retorno dos clocks. A latência do núcleo em ciclos continua definida, mas a entrega ao mestre pode esperar indefinidamente.

76. **Por que reset assíncrono com liberação sincronizada?** Assert precisa atuar mesmo sem SCLK; deassert próximo a uma borda pode violar recovery/removal. A liberação local controla esse risco.

77. **Como reset afeta uma operação em andamento?** Aborta, zera operandos, saída, máscaras, flags e as duas pontas do handshake. O mestre reinicializa e recarrega os dados.

78. **O que acontece com reset se SCLK não oscilar?** O domínio SPI pode permanecer em reset indefinidamente, pois a liberação sincronizada precisa de bordas. Quatro períodos com CS_N alto são condição provisória, ainda não garantida pelo mestre. Perguntar obrigatoriamente ao professor quem fornece esses clocks e qual alternativa usar se isso não for possível.

79. **CS_N alto pode limpar o handshake?** Não. Ele apenas encerra/aborta o frame e desabilita MISO. Banco e sincronizadores precisam preservar a transação entre seleções.

80. **Por que não sincronizar CS_N com dois FF como req?** CS_N faz parte do protocolo temporizado em SCLK; atrasá-lo pode perder bits iniciais. Seu framing usa temporização de pino e cuidado com liberação do clear local.

## Perguntas difíceis: concorrência, verificação e potência

81. **Se CLR_DONE coincidir com a chegada do resultado, quem vence?** A publicação do resultado. DONE fica em 1; isso evita perder a notificação de conclusão.

82. **Se START coincidir com BUSY baixando, ele é aceito?** A elegibilidade usa BUSY anterior à borda. Se era 1, o comando é rejeitado; o mestre deve observá-lo livre antes de iniciar.

83. **Como tratar ERROR e CLR_ERROR no mesmo ciclo?** Um erro novo ganha do clear. ERROR anterior não bloqueia operações admissíveis, mas permanece até limpeza explícita ou reset.

84. **Pode ler um STATUS antigo mesmo após o hardware mudar?** Sim. A palavra é congelada no fim do endereço e usa o estado anterior àquela borda. Polling deve repetir a leitura.

85. **O que acontece com um frame de escrita incompleto?** CS_N alto descarta o staging, sem mudar a palavra nem sua máscara. Uma escrita só é efetivada na 48ª subida.

86. **E se houver mais de 48 clocks com CS_N baixo?** O frame completo já foi efetivado; clocks extras são ignorados até a próxima seleção. Não ocorre uma segunda escrita implícita nem rollback.

87. **Qual parte deve consumir mais área?** As S-boxes são candidatas relevantes, junto com armazenamento e muxes. A predominância real depende de síntese; não há percentual medido nesta entrega.

88. **Quais decisões ajudam low power futuramente?** Reuso de rodada, enables de registradores e entradas estáveis criam pontos de controle de atividade. Compararemos também cache de chaves e isolamento de operandos com dados medidos.

89. **Clock enable já desliga a árvore de clock?** Não necessariamente. Ele pode apenas impedir alteração do dado. Clock gating físico requer células e fluxo adequados, além de verificação de wake-up e teste.

90. **Dois clocks exigem dois domínios de potência no UPF?** Não. Clock e alimentação são partições diferentes. Domínios de potência, isolamento e retenção serão definidos só após requisitos e análise.

91. **Como verificar a arquitetura antes de existir AES funcional?** Revisar contratos, tabelas de ciclos, endereços, prioridades e invariantes com o parceiro. Testes funcionais de AES/CDC são planejados, não apresentados como executados agora.

92. **Quais propriedades formais seriam úteis depois?** Unicidade de start por pedido, estabilidade dos dados pendentes, ausência de overwrite, rodada final correta no controle e conclusão eventual sob hipóteses explícitas de clocks/reset.

93. **Formal digital prova ausência de metastabilidade?** Não. Pode demonstrar propriedades do protocolo sob modelo abstrato; análise física, restrições e MTBF continuam necessários.

94. **Como testar o algoritmo sem repetir o mesmo erro no modelo?** Usar vetores e estados intermediários de referência independente, incluindo round keys e ordenação de bytes, além de testes unitários das transformações.

95. **Qual a principal fragilidade da proposta?** Depender de hipóteses funcionais e físicas ainda não confirmadas. Os maiores riscos de implementação são timing de rodada/expansão e CDC/reset com SCLK pausado.

96. **O que precisa perguntar ao professor antes de avançar?** Variantes/operações, mestre SPI e clocks de inicialização, frequências/temporização, reset, tecnologia/ferramentas, metas de energia e escopo de segurança.

97. **Por que SPI modo 0 é provisório?** O instrutor ainda não confirmou CPOL/CPHA nem o mestre. Modo 0 permite um contrato concreto para discussão, mas outro modo mudaria bordas de amostragem/lançamento, primeiro bit e testes; a referência SPI não escolhe o modo do projeto.

98. **Estados da FSM, ciclos internos e latência são a mesma coisa?** Não. Há quatro estados distintos; ROUND é reutilizado por nove ciclos. São onze ciclos de cálculo E0→E11, publicação após E11 e captura pelo adaptador em E12. DONE de software inclui CDC e pode demorar mais.

99. **Qual é a diferença entre done, DONE e BUSY?** done é pulso de um ciclo em clk_sys; DONE é flag sticky em SCLK após captura do resultado; BUSY indica slot transacional ocupado até fechar o handshake. busy minúsculo é apenas a execução interna. BUSY=1/DONE=1 durante fechamento é permitido.

100. **Qual risco provavelmente aparecerá primeiro na síntese?** A hipótese inicial é o custo de área das vinte S-boxes ou o timing do pior caminho de Round Logic/Key Expansion. Só síntese mapeada com biblioteca e restrições permite avaliar; potência ainda requer atividade representativa. Não se trata de previsão comprovada.

## Como estudar e conferir respostas

- Desenhar à mão os cinco blocos externos e o retorno; localizar onde cada registrador recebe clock.
- Reproduzir a tabela E0–E12 sem confundir bordas, períodos, estados da FSM e DONE de software.
- Explicar por que a expansão fica uma rodada adiantada e por que são 16 + 4 S-boxes.
- Simular em papel uma chave parcial, START rejeitado e substituição de chave já completa.
- Percorrer as quatro fases com SCLK parado em cada uma; identificar dados que permanecem estáveis.
- Diferenciar done local, DONE sticky, BUSY do slot, latência e throughput.
- Preparar duas críticas à própria escolha: perda de vazão pelo handshake e recálculo da expansão com chave reutilizada.

Referências para consulta: [FIPS 197-upd1](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf), [SPI — Analog Devices](https://www.analog.com/en/resources/analog-dialogue/articles/introduction-to-spi-interface.html) e as seções específicas da [arquitetura](../architecture/arquitetura_v1.0.md). As contagens de ciclos, mapa e handshake são decisões deste projeto, não prescrições dessas fontes.
