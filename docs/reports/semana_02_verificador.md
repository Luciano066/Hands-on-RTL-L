> **Histórico de 09/10/2026, contrato v1.0 superado.** Em 29/10/2026,
> a leitura do Block Guide motivou a [arquitetura v1.1](../architecture/arquitetura_v1.1.md).
> Use o [relatório/roteiro de retomada](semana_02_retomada.md) para a defesa atual
> e o [relatório da Semana 3](semana_03.md) para os testes AES. Semana 2 segue
> sem apresentação/aceite registrados. As afirmações abaixo descrevem a entrega antiga.

# Pacote de apresentação e revisão com o verificador — Semana 2

**Status: material preparado; apresentação, concordância e execução dos testes abaixo ainda pendentes.** Data de preparação: 09/10/2026. Não houve envio automático a terceiros nem reunião registrada.

## 1. Leitura e reunião sugeridas

Ler a [arquitetura v1.0](../architecture/arquitetura_v1.0.md) como contrato principal e consultar os [ADRs](../architecture/decisoes_semana_02.md) para justificativas. O [roteiro de defesa](semana_02_defesa.md) oferece perguntas progressivas.

Status uniforme para a revisão: AES-128 e somente cifragem são hipóteses funcionais; SPI modo 0 é baseline provisório; reset ativo baixo e expansão adiantada são decisões arquiteturais provisórias; 16 + 4 S-boxes são hipótese a validar por síntese. Todas dependem da confirmação do instrutor; nenhuma é requisito oficial confirmado. Os testes abaixo expressam o comportamento condicional dessa proposta.

Apresentação de aproximadamente 15 minutos:

1. Escopo e diagrama (3 min): domínio de cada registrador, hipótese AES-128 e ausência de RTL funcional novo.
2. Interface e ciclos (3 min): E0–E11, pulso done, saída retida, geração de chave adiantada.
3. SPI e banco (4 min): frame, mapa, máscaras e comandos concorrentes.
4. CDC/reset (3 min): quatro fases, clocks pausados e reset comum.
5. Revisar dúvidas e responsabilidades (2 min): registrar divergências antes de implementar testes dependentes de decisões ainda abertas.

## 2. Contratos que precisam de concordância explícita

| Tema | Contrato proposto | Referência na arquitetura |
|---|---|---|
| Escopo | AES-128, somente cifragem da primitiva; hipótese a confirmar | Seção 1 |
| Empacotamento | Palavra 0 em bits 127:96; byte 0 em 127:120; colunas do State | 9.1 |
| Ciclos / FSM | 11 ciclos de cálculo após start local em E0; saída/done após E11; adaptador captura E12; quatro estados distintos; DONE SPI variável | 9.3–9.4 e 10 |
| Chaves / S-boxes | Expansão adiantada provisória: K1 em INIT, K(r+1) em paralelo; hipótese de 16 + 4 S-boxes a validar por síntese | 11 |
| SPI | Modo 0 como baseline provisório; 48 clocks, opcodes 0x02/0x03, endereço em bytes | 12.1 |
| Snapshot | Leitura após 16ª subida; dados na 17ª–48ª; valor anterior à borda de snapshot | 12.1 e 13 |
| Banco | STATUS 0x00; CONTROL 0x04; VALID_MASK 0x08; janelas 0x20/0x30/0x40 | 12.2 |
| Máscaras | KEY_VALID_MASK e DATA_IN_VALID_MASK de quatro bits; reset zero; ambas 1111 para aceitar; reinício do conjunto na substituição; consumo de DATA_IN no START | 12.3 |
| Ocupação | BUSY cobre pedido, AES, resposta e fechamento; sem fila | 7 e 13 |
| Conclusão / limpeza | done local pulsado; DONE sticky nasce com captura SPI; limpa por START aceito/reset/CONTROL.CLR_DONE=1, nunca por leitura; STATUS é RO | 7.3 e 13.1 |
| Prioridades | Reset domina; evento novo vence clear; elegibilidade usa estado anterior à borda | 13 |
| CDC | Onze etapas explícitas; dois FF para req em clk_sys e ack_done em SCLK; 256/128 bits estáveis sem sincronização bit a bit; STATUS é local | 7.2 |
| Reset | Baixo e comum como decisão provisória; liberação SPI pode ficar bloqueada sem SCLK; condição de clocks de inicialização ainda a confirmar | 6 |

Nenhum teste deve assumir “AES pronto em dez ciclos”, “busy do banco é busy do núcleo” ou “CS_N reinicia todos os registradores”. Essas interpretações divergem do contrato proposto.

## 3. Matriz de verificação futura

Esta matriz planeja verificações das próximas semanas; **não é evidência de testes AES/SPI/CDC executados nesta entrega**. Usar referência independente, incluindo [exemplos intermediários do NIST](https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines/example-values), conforme operações que forem aprovadas.

| ID | Cenário | Resultado / propriedade a verificar |
|---|---|---|
| V01 | Empacotar 00 11 ... FF | Primeira coluna 00 11 22 33 e fatias de palavras corretas |
| V02 | SubBytes unitário | Todas as 256 entradas correspondem à função oficial |
| V03 | ShiftRows unitário | Permutação exata e ausência de transposição |
| V04 | MixColumns unitário | Resultados independentes por coluna e aritmética de campo correta |
| V05 | Round keys oficiais | K0..K10 corretas e disponíveis na rodada certa |
| V06 | Cifragem completa oficial | Ciphertext e estados intermediários correspondentes |
| V07 | Cronograma normal | Aceitação local E0; 11 ciclos de cálculo; done/data_out após E11, ambos capturados pelo adaptador em E12; não confundir com STATUS.DONE |
| V08 | Start no núcleo com busy=1 | Ignorado; operação e latência não mudam |
| V09 | Entradas mudam depois de E0 | Cálculo usa a captura original |
| V10 | Início isolado em E12 | Novo bloco aceito; expansão reinicia de K0 |
| V11 | Escritas SPI das quatro palavras | Commit somente na 48ª subida, MSB primeiro |
| V12 | Abort de escrita em cada posição antes de 48 | Sem mudança no banco ou na máscara; próximo frame recomeça corretamente |
| V13 | Frame completo e clocks extras | Uma única operação; extras ignorados até CS_N alto |
| V14 | Leitura SPI e primeiro bit | Snapshot em 16; bit 31 em 17; sem deslocamento de um bit |
| V15 | Leitura STATUS concorrente com conclusão | Snapshot antigo permitido; próximo polling reflete estado novo |
| V16 | Opcode/endereço inválido ou desalinhado | Sem alias; leitura zero; ERROR na conclusão do frame |
| V17 | Escrita em RO ou bit reservado CONTROL | Nenhuma alteração útil; ERROR=1 |
| V18 | Todas as máscaras parciais | START rejeitado até ambas serem 1111; palavra zero conta como válida |
| V19 | Substituir uma palavra de chave já completa | Nova máscara de um bit; START não usa chave mista |
| V20 | Escritas fora de ordem / repetidas | Bits de validade por índice; quatro índices distintos necessários |
| V21 | Reuso de chave entre blocos | KEY_READY preservado; DATA_READY consumido e exige quatro novas palavras |
| V22 | Escrever operandos ou START durante BUSY | Ignorado, ERROR; sem corrupção, fila ou restart |
| V23 | CLR_DONE e conclusão na mesma borda | DONE=1 e DATA_OUT novo |
| V24 | CLR_ERROR e erro novo na mesma borda | ERROR=1 |
| V25 | Liberação BUSY junto com START/escrita | Decide pelo BUSY anterior; rejeita se antes estava ocupado |
| V26 | Ler DATA_OUT antes de DONE | Valor retido anterior, nunca State intermediário |
| V27 | Ler quatro palavras após DONE sem novo START | Vetor íntegro da mesma operação |
| V28 | CDC com razões/fases variadas | Uma aceitação, uma execução, uma resposta por transação |
| V29 | Parar SCLK após START e em cada fase | Dados/níveis retidos; retomada conclui sem duplicação |
| V30 | CS_N alto entre comandos | Handshake continua preservado; sincronizadores operam com bordas de SCLK |
| V31 | Reset em cada fase CDC/rodada/frame | Operação abortada, tudo zerado, nenhuma resposta fantasma após reinicializar |
| V32 | Reset liberado sem SCLK | SPI permanece em reset; inicialização com clocks restaura operação |
| V33 | Retorno a zero atrasado | DONE pode ser 1 com BUSY=1; próximo START aguarda slot livre |
| V34 | Estabilidade dos dados de origem | key/din constantes durante BUSY; result_hold constante durante confirmação |
| V35 | Análise CDC/RDC e timing | Estruturas reconhecidas, reset correto, restrições dos barramentos e meia fase válidas |
| V36 | Perfil de atividade futuro | Comparar energia/área sob chave fixa/variável e períodos de ociosidade |
| V37 | Limpeza DONE por leitura versus escrita | Polling não limpa; CONTROL.CLR_DONE=1 limpa; escrita direta em STATUS é rejeitada |
| V38 | FSM e captura final | Quatro estados distintos; State e data_out recebem o resultado combinacional final em E11, não o State anterior |
| V39 | Revisão das hipóteses após respostas do instrutor | Ajustar testes de variante, decifragem, modo SPI e reset se a baseline mudar |

Separar propriedades de **segurança digital** (nunca duplicar, nunca sobrescrever) de **progresso** (eventualmente concluir). Progresso assume clocks retomados, reset liberado e núcleo funcional. Simulação de clocks aleatórios não mede metastabilidade; V35 exige análise física apropriada.

## 4. Rastreabilidade das entregas oficiais

| Entrega da Semana 2 | Evidência preparada | Situação |
|---|---|---|
| 1. Diagrama de blocos | Arquitetura, seção 4, Mermaid | Preparado |
| 2. Interfaces entre módulos | Arquitetura, 4.1 e 10 | Preparadas |
| 3. Clock/reset | Arquitetura, 5–6 | Propostos; parâmetros da plataforma pendentes |
| 4. Travessia SPI/sistema | Arquitetura, 7 | Proposta; validação física futura |
| 5. Microarquitetura | Arquitetura, 8–9; D01/D04/D05 | Comparada e escolhida como baseline |
| 6. Interface AES | Arquitetura, 10 | Contrato preparado |
| 7. Mapa | Arquitetura, 12–13 | Contrato preparado |
| 8. Documento v1.0 | Arquitetura completa e ADRs | Preparado |
| 9. Defesa curta | Roteiro de cinco minutos e 100 perguntas | Preparada; defesa ainda não realizada |
| 10. Apresentar ao parceiro | Este pacote e pauta de revisão | Material preparado; apresentação pendente |
| Aceite do instrutor | Registro abaixo | Pendente |

## 5. Registro de revisão a preencher após acontecer

| Campo | Registro |
|---|---|
| Verificador parceiro | A informar |
| Data e forma de apresentação | A realizar |
| Revisão/commit efetivamente apresentado | A registrar após versionamento |
| Contratos aceitos pelo parceiro | Não registrados ainda |
| Dúvidas/divergências e responsáveis | A registrar na revisão |
| Respostas do instrutor às pendências | Não recebidas nesta entrega |
| Data da defesa e decisão do instrutor | Pendente |
| Ajustes exigidos antes de aceite | A registrar após avaliação |

Após a reunião, registrar fatos e decisões neste quadro, atualizar pendências/ADRs se necessário e só então avaliar o encerramento da Semana 2. A tag sugerida identifica a revisão documental; por si só não representa aprovação acadêmica.
