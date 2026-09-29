# Backlog — Acelerador AES + SPI

## Convenção e escopo

- [ ] Pendente, sem afirmar implementação.
- [x] Entregue ou validado com evidência.

As semanas 2 a 6 preservam a organização do backlog recebido e constituem planejamento preliminar; datas, escopo e critérios finais dependem do instrutor. As decisões abertas estão em [P01–P13](docs/spec/pendencias.md).

## Semana 1 — Estudo, ambiente e entrega

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
- [ ] Definir hospedagem remota e política de versionamento, se exigidas.

## Semana 2 — Arquitetura e microarquitetura

- [ ] Resolver variantes AES e suporte a cifragem/decifragem.
- [ ] Definir diagrama de blocos e interfaces entre módulos.
- [ ] Definir estratégia de clock/reset e seus requisitos temporais.
- [ ] Comparar alternativas de CDC e requisitos para coerência dos dados.
- [ ] Comparar arquitetura iterativa, serializada, parcialmente ou totalmente desenrolada.
- [ ] Avaliar S-box, expansão e armazenamento de round keys conforme metas.
- [ ] Fixar representação RTL do State e conversões de entrada/saída.
- [ ] Definir protocolo SPI, interface do núcleo e eventual mapa de registradores.
- [ ] Preparar documento de arquitetura após registrar as decisões e justificativas.

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
