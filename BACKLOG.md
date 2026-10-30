# Backlog — MiniSoC AES

Atualização: 30/10/2026. [x] indica execução/evidência técnica; aceite humano
é listado separadamente. Fonte funcional: Block Guide v1.0.0 local confidencial.
Contrato atual: [arquitetura v1.1](docs/architecture/arquitetura_v1.1.md).

## Cronograma de 13 semanas

Informações do comunicado do professor confirmadas pelo solicitante em
30/10/2026. Este calendário substitui a distribuição de atividades proposta
na primeira revisão de 30/10, preservada no commit `a81d782`.
Os títulos Semana 1–6 no histórico abaixo identificam entregas anteriores.

| Item | Informação confirmada |
|---|---|
| Duração | 13 semanas |
| Data inicial | A confirmar; não explicitada no comunicado disponível |
| Entregas semanais | Sextas-feiras |
| Recesso | 21/12/2026 a 03/01/2027 |
| Encerramento | 29/01/2027 |

| Data | Entrega / atividade | Situação em 30/10 |
|---|---|---|
| 30/10/2026 | Desafio SubBytes e ShiftRows, com módulos combinacionais, TB autochecking e relatório da Semana 2 | Implementação e 647 checks PASS; aceite pendente |
| 06/11/2026 | Microarquitetura e demais transformações de rodada; contato com DV | Datapath existente com 2.345 checks PASS; revisão da entrega e contato pendentes |
| 04/12/2026 | RTL v1.0 contemplando ECB, CBC e CTR; contato com DV | Entrega e contato futuros; modos não implementados |
| 08/01/2027 | RTL v1.1 acrescentando PCBC, CFB e OFB; contato com DV | Entrega e contato futuros; modos não implementados |
| 22/01/2027 | Contato com DV | Programado; pauta a combinar |
| 29/01/2027 | Encerramento | Futuro; aceite humano pendente |

A data inicial e as datas das demais entregas permanecem a confirmar, sem
preenchimento por contagem retroativa das semanas. Critérios detalhados de
aceite ainda precisam ser alinhados. O replanejamento não autoriza antecipar
funcionalidades nesta correção.

## Desafio obrigatório de 30/10/2026

- [x] Auditar a `develop` em `5043910` e executar a regressão anterior.
- [x] Expor `minisoc_aes_sbox`, `minisoc_aes_sub_bytes` e `minisoc_aes_shift_rows` como módulos combinacionais.
- [x] Reutilizar funções AES e preservar package, datapath, expansão e core.
- [x] Documentar interfaces e byte 0 em `[127:120]`, com State por colunas.
- [x] Testar S-box 256/256, todas as posições SubBytes e FIPS B rodadas 1 e 10 separadamente.
- [x] Integrar alvo `test-aes-transforms` à regressão e ao comando PowerShell existente.
- [x] Executar lint sem erros/warnings, 647 checks novos e regressão de 8.655 checks AES + quatro XOR.
- [x] Confirmar que quatro falhas deliberadas são detectadas pelo TB em cópias locais ignoradas.
- [x] Preservar relatório anterior em `docs/reports/semana_02_historico_2026-10-09.md`.
- [x] Atualizar relatório, README, vetores e planejamento, sem incluir o Block Guide.
- [x] Registrar duração, entregas às sextas, encerramento, recesso, marcos e contatos programados confirmados pelo comunicado.
- [ ] Confirmar data inicial, datas das demais entregas e critérios detalhados de aceite.
- [ ] Revisar dúvidas das seções 1–3 e 8 com o professor e o parceiro.
- [ ] Apresentar o desafio e registrar aceite real do professor.

## Contatos com o verificador parceiro

Nenhum contato efetivamente realizado está documentado nos registros
disponíveis. Nome do parceiro, data de contato realizado, canal utilizado e
retorno: **não informado/sem registro**. Não há aceite do verificador obtido.
Após cada contato, registrar também revisão/commit apresentado e pendências no
[relatório atualizado](docs/reports/semana_02.md#6-dúvidas-e-contato-com-o-verificador).

As datas abaixo estão confirmadas como programadas; as pautas são propostas:

- [ ] 06/11/2026 — revisar microarquitetura, transformações, portas, State, vetores e dúvidas do guia.
- [ ] 04/12/2026 — revisar RTL v1.0 (ECB, CBC e CTR), interfaces de integração e divergências de DV.
- [ ] 08/01/2027 — revisar RTL v1.1 (acréscimo de PCBC, CFB e OFB), regressão e pendências de aceite.
- [ ] 22/01/2027 — alinhar pauta e revisar evidências/pendências para o encerramento de 29/01.

As ações acima estão programadas, sem registro de realização; esta correção
não envia mensagens ao parceiro.

## Histórico — Semana 1: estudo, ambiente e entrega — concluída

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

## Histórico — Semana 2: arquitetura revisada, aceite pendente

- [x] Auditar main/faaf745, árvore limpa e fontes da Semana 2.
- [x] Ler integralmente Block Guide e revisão técnica recebidos.
- [x] Criar branch dedicada à revisão arquitetural v1.1 e preservar arquitetura v1.0.
- [x] Corrigir escopo, portas, clocks/reset, SPI, mapa, RAM e cipher/inverse/modos.
- [x] Registrar supersessão dos ADRs e questões P14–P27 com perguntas verificáveis.
- [x] Preparar checklist/roteiro no relatório de retomada.
- [ ] Apresentar ao parceiro de DV e registrar divergências/concordância real.
- [ ] Obter respostas do instrutor aos pontos OPEN de integração.
- [ ] Defender, incorporar correções e registrar aprovação do instrutor.

As entregas documentais anteriores continuam históricas. Frame de 48 bits,
mapa em bytes, VALID_MASK e payload SPI foram substituídos. Confirmação de
requisitos no guia não encerra a Semana 2.

## Histórico — Semana 3: datapath implementado e testado, aceite pendente

- [x] Implementar SubBytes, ShiftRows, MixColumns e AddRoundKey.
- [x] Implementar InvSubBytes, InvShiftRows e InvMixColumns.
- [x] Compor rodada inicial, normal e final forward/inverse em RTL combinacional.
- [x] Verificar ordem por colunas e empacotamento das quatro palavras.
- [x] Testar 256 entradas S-box/inversa com oráculo algébrico independente.
- [x] Testar misturas por matriz independente, base linear e estados determinísticos.
- [x] Conferir estados intermediários e quatro KATs NIST em ambos os sentidos.
- [x] Adicionar alvos Make/scripts AES e executar lint/sim e regressão XOR.
- [x] Registrar versões, comandos, resultados e limites em semana_03.md.
- [ ] Apresentar resultados e obter aceite do instrutor.

## Histórico — Semana 4: expansão e controle AES implementados/testados, aceite pendente

- [x] Auditar branch be42888 limpa, registrar hashes de 36 arquivos e reexecutar regressão anterior.
- [x] Centralizar receitas/diretório do Makefile, preservando os alvos antigos.
- [x] Implementar minisoc_aes_key_exp.sv e comparar K0..K10 com FIPS A.1 e C.1.
- [x] Armazenar onze chaves e disponibilizar índices em ordem direta/inversa; sem cache entre operações.
- [x] Implementar minisoc_aes_core auxiliar com State, direção, contador e FSM, reutilizando o datapath intacto.
- [x] Validar KATs cipher/inverse, captura, BUSY, pulso DONE, retenção da saída e operações consecutivas.
- [x] Testar reset/abort nos dez passos de expansão e 42 cortes do core em ambos os sentidos.
- [x] Executar lint/simulação/regressão e síntese genérica, registrando latências de 10/21 ciclos.
- [x] Documentar contrato interno D20 e resultados em docs/reports/semana_04.md.
- [ ] Planejar controlador de modos, guarda de ciphertext original e RAM in-place.
- [ ] Apresentar resultados e registrar aceite do instrutor; manter P14–P27 OPEN.

`minisoc_aes_top` permanece reservado ao futuro engine; o core atual é de um
bloco. DONE pulsado e START ocupado ignorado são escolhas locais, sem fechar
políticas oficiais de status/concorrência do MiniSoC.

## Pendências herdadas — SPI, controle e CDC (antiga Semana 5)

- [ ] Resolver P14/P21/P22/P24/P25 com instrutor e DV antes de fixar o protocolo detalhado.
- [ ] Implementar minisoc_spi.sv: Mode 0, frame de 40 bits, read em duas transações.
- [ ] Implementar mapa oficial, banco always-on e transporte de frame por evento/toggle.
- [ ] Testar abort/back-to-back/reset/clocks pausados e ausência de commit duplicado.
- [ ] Implementar snapshots de configuração/status com verificação de coerência CDC.

## Pendências herdadas — memória, PLL e integração (antiga Semana 6)

- [ ] Resolver contrato idle/mux de clock da RAM e latência de leitura (P18/P19).
- [ ] Implementar RAM 1024 x 32 sem reset, ownership exclusivo e acesso externo síncrono.
- [ ] Implementar PLL mock /1,/2,/4,/8, lock e sequência de reset aprovada.
- [ ] Implementar seis modos, 1..256 blocos, erros e processamento in-place.
- [ ] Integrar minisoc_top.sv apenas com portas oficiais e testar ponta a ponta.
- [ ] Testar limites 0/1/256/257, modos reservados, feedback e troca de owner.
- [ ] Executar análise CDC/RDC e clock com ferramentas/restrições apropriadas.

## Critérios e etapas físicas futuras

- [ ] Confirmar tecnologia/PDK, ferramentas oficiais e IP AES de referência (P27).
- [ ] Definir metas e medir síntese, timing, potência e energia com atividade representativa.
- [ ] Avaliar enables, isolamento e células seguras de gating; não usar mux/gating combinacional ingênuo.
- [ ] Definir UPF somente após requisitos reais de alimentação/retenção/isolamento.
- [ ] Criar tags de entrega somente com status técnico/humano explícito; sem push/merge automático.
