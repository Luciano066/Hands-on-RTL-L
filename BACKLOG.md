# Backlog — Acelerador AES + SPI

## Convenção e escopo

- [ ] Pendente, sem afirmar implementação.
- [x] Entregue ou validado com evidência.

Os requisitos da Semana 2 seguem o pedido atual, com aceite pela defesa aprovada pelo instrutor. As semanas 3 a 6 preservam o planejamento preliminar recebido; datas e critérios finais dependem do curso. As decisões abertas e as baselines propostas estão em [P01–P13](docs/spec/pendencias.md).

## Semana 1 — Estudo, ambiente e entrega — concluída

Base validada e versionada: tag `w01-v1.0`, HEAD inicial desta entrega `de477dd`. Fontes e relatórios históricos preservados.

- [x] Inspecionar os sete arquivos originais antes de alterações.
- [x] Normalizar a raiz e completar docs/spec, docs/architecture, formal, syn e upf.
- [x] Inicializar repositório Git local, com exclusão de ferramentas e artefatos gerados.
- [x] Documentar dependências, preparação e execução no README.
- [x] Manter RTL mínimo de XOR e testbench autochecking separado.
- [x] Garantir a cadeia lint → compilação → simulação e códigos de erro.
- [x] Preparar scripts Bash e PowerShell e instalação portátil Windows com hashes.
- [x] Executar make clean e make smoke com ferramentas abertas.
- [x] Verificar cópia limpa, make -j4 e falhas de dependência, lint, compilação e simulação.
- [x] Registrar versões, comandos, warnings e resultados em semana_01_validacao.md.
- [x] Revisar relatório de AES, SPI e CDC, com referências.
- [x] Elaborar defesa com decisões, alternativas, trade-offs e 60 perguntas.
- [x] Registrar explicitamente decisões funcionais pendentes.

## Dependências do curso, sem bloquear o smoke aberto

- [ ] Receber especificação funcional e critérios de aceite das próximas etapas.
- [ ] Identificar e validar ferramentas oficiais fornecidas pelo instrutor, se diferentes.
- [ ] Registrar tecnologia e versão do PDK/FPGA quando informadas; o smoke não usa PDK.
- [ ] Confirmar política de branches, publicação e aceite das próximas tags, se exigida pelo curso.

## Semana 2 — Arquitetura e microarquitetura — em revisão, não concluída

### Material preparado

- [x] Ler toda a Semana 1 e registrar [diagnóstico antes das alterações](docs/reports/semana_02_diagnostico.md).
- [x] Definir proposta de diagrama Mermaid e interfaces entre módulos.
- [x] Definir proposta de dois clocks independentes, reset e inicialização com SCLK pausável.
- [x] Comparar pulse/toggle/handshake/FIFO/shadow registers e especificar captura estável com quatro fases.
- [x] Comparar arquiteturas iterativa, serializada, parcialmente e totalmente desenrolada.
- [x] Escolher baseline iterativa e justificar recursos, timing, vazão e consumo sem métricas inventadas.
- [x] Comparar S-box e Key Expansion; alinhar organização de 16 + 4 S-boxes com o cronograma.
- [x] Fixar empacotamento do State e cronograma E0–E11 no contrato proposto.
- [x] Definir interface do núcleo, protocolo SPI, mapa, máscaras e START/BUSY/DONE/ERROR.
- [x] Preparar [arquitetura v1.0](docs/architecture/arquitetura_v1.0.md) e [12 ADRs](docs/architecture/decisoes_semana_02.md).
- [x] Preparar [defesa curta e 100 perguntas/respostas](docs/reports/semana_02_defesa.md).
- [x] Registrar 20 riscos com criticidade/mitigação e perguntas ao professor.
- [x] Preparar [pacote do verificador](docs/reports/semana_02_verificador.md) com contratos, pauta e testes futuros.

### Decisões propostas

AES-128 e somente cifragem são hipóteses funcionais; SPI modo 0 é baseline provisório; reset ativo baixo e expansão adiantada são decisões arquiteturais provisórias; 16 + 4 S-boxes são hipótese a validar por síntese. Nenhuma dessas escolhas é requisito oficial confirmado. O contrato provisório usa datapath de 128 bits, banco de palavras de 32 bits em SCLK, núcleo em clk_sys e handshake de quatro fases. DONE sticky e máscaras de completude pertencem ao banco.

### Revisão documental solicitada antes da defesa

- [x] Uniformizar status provisório das seis escolhas nos documentos atuais, preservando o histórico da Semana 1.
- [x] Separar 11 ciclos de cálculo/publicação E0–E11, captura em E12 e quatro estados da FSM; DONE SPI possui latência variável.
- [x] Justificar 16 + 4 S-boxes, compartilhamento e validação futura por síntese/STA/atividade.
- [x] Explicitar onze etapas do handshake, origem/destino, sinais de dois FF e dados multibit estáveis.
- [x] Manter reset SPI com SCLK parado como risco alto aberto, comparar alternativas e formular pergunta obrigatória ao professor.
- [x] Distinguir done/DONE/BUSY, comparar políticas de limpeza e detalhar KEY_VALID_MASK/DATA_IN_VALID_MASK.
- [x] Classificar natureza de cada registrador e ampliar riscos de variante, decifragem, SPI, frequências e tecnologia.
- [x] Reexecutar smoke sem warnings; conferir links, dois diagramas Mermaid em renderizador compatível, endereços e status das decisões; confirmar hashes dos 16 arquivos preservados da Semana 1.

### Pendências essenciais e aceite

- [ ] Confirmar com o instrutor AES-128, operações e eventual modo criptográfico (P01/P02/P13).
- [ ] Confirmar compatibilidade do mestre com SPI modo 0, frame e clocks de inicialização (P03/P05/P06).
- [ ] Obter frequências/temporização, metas físicas, tecnologia e ferramentas de validação (P04/P11/P12); registrar o que é necessário para aprovação arquitetural e o que será detalhado na implementação.
- [ ] Apresentar a arquitetura ao verificador parceiro e registrar concordância/divergências reais.
- [ ] Realizar defesa, incorporar correções e registrar **aprovação do instrutor**.
- [ ] Encerrar a Semana 2 somente após os itens essenciais de aceite.

### Perguntas para levar ao professor

- Quais variantes, cifragem/decifragem e modos são exigidos?
- O mestre aceita o mapa/protocolo, clocks com CS_N alto na inicialização e polling para liberar o handshake?
- Reset ativo baixo comum aos domínios é compatível? Há reset independente? **Quem fornece SCLK para liberar reset se o mestre estiver parado, e qual alternativa adotar se ele não fornecer clocks com CS_N alto?**
- Quais frequências, duty cycle, setup/hold, latência, vazão, área, energia e MTBF são exigidos?
- Qual PDK/FPGA e quais ferramentas de síntese, formal, CDC/RDC e UPF serão usados?
- Há requisito de proteger leitura da chave, zeroização ou canais laterais?
- Como registrar o aceite do instrutor e a revisão do parceiro?

Relatório da entrega e limites da verificação: [semana_02.md](docs/reports/semana_02.md). Não antecipar as implementações abaixo para esta entrega.

## Semana 3 — Datapath AES

- [ ] Implementar SubBytes.
- [ ] Implementar ShiftRows.
- [ ] Implementar MixColumns.
- [ ] Implementar AddRoundKey.
- [ ] Testar funções com referências oficiais e conferir estados intermediários.

## Semana 4 — Key Expansion e controle

- [ ] Implementar expansão de chave conforme variantes aprovadas.
- [ ] Implementar FSM/controle, incluindo a distinção da última rodada.
- [ ] Integrar datapath, key schedule e controle.
- [ ] Validar round keys e vetores oficiais nas operações suportadas.

## Semana 5 — SPI e interface de controle

- [ ] Implementar SPI conforme CPOL/CPHA, ordem dos dados e temporização definidos.
- [ ] Implementar mecanismo de CDC aprovado e verificar reset/domínios.
- [ ] Implementar banco de registradores ou alternativa aprovada.
- [ ] Testar leitura/escrita, limites de transação e comandos durante busy.

## Semana 6 — Integração

- [ ] Integrar SPI, interface de controle e AES.
- [ ] Criar teste ponta a ponta com referência independente.
- [ ] Executar análise de CDC com ferramentas e restrições apropriadas.
- [ ] Revisar cobertura e critérios antes de congelar RTL v1.0.

## Etapas futuras — Baixo consumo e implementação física

- [ ] Definir metas de área, timing, potência e energia por operação.
- [ ] Obter resultados de referência com estímulos representativos.
- [ ] Avaliar clock enable, isolamento de operandos e gating conforme tecnologia.
- [ ] Descrever UPF caso existam domínios de potência que o exijam.
- [ ] Validar equivalência/comportamento e medir ganhos das técnicas escolhidas.
