# Escopo confirmado e decisões pendentes

## Situação vigente — 29/10/2026

Fonte primária recebida e lida: Block Guide MiniSoC AES v1.0.0 (15 páginas,
confidencial). Revisão técnica recebida e lida como interpretação proposta.
Contrato vigente: [arquitetura v1.1](../architecture/arquitetura_v1.1.md).
R = requisito da fonte; D = decisão proposta; H = hipótese; P = pendência OPEN.
As seções posteriores à tabela atual são histórico de 09/10/2026.

| IDs antigos | Evolução frente ao guia |
|---|---|
| P01/P02/P13 | R: AES-128 cipher/inverse, seis modos e 1..256 blocos; escopo principal respondido |
| P03/P05 | R: Mode 0 MSB-first, 40 bits, seis bits de endereço, read em dois frames e mapa do guia; detalhe de retorno P14 |
| P04 | R: clk 2 GHz, SCLK ≤25 MHz, mem_clk ≤200 MHz, divisores /1,/2,/4,/8; metas físicas continuam P27 |
| P06 | R: rst_n baixo, RAM não reseta, AES aguardando lock/inicialização; detalhes P20/P21 |
| P07/P08/P10 | D18/D19: rodada iterativa proposta, unidade combinacional implementada; expansão/cache e custo físico ainda a validar |
| P09 | R: serial em SCLK, banco em clk always-on, evento/toggle de frame; outras travessias D14/D15 e P22/P23 |
| P11/P12 | Sem dados novos de tecnologia, potência ou ferramentas oficiais; P27 |

Não preservar como oficiais o mapa antigo, máscaras, comandos CLR ou exigência
de quatro clocks SCLK com CS alto. A inicialização do banco always-on independe
de SCLK; a disciplina do serializador continua pendente.

## Perguntas atuais ao instrutor/DV

Todos os itens abaixo são **P / OPEN**, sem resposta atribuída ao instrutor.
As propostas D não fecham estes itens por conta própria.

| ID | Pergunta verificável | Impacto / proposta atual |
|---|---|---|
| P14 | Em qual borda/posição do segundo frame começam os 32 bits MISO? Qual RWb/dummy/NOP deve ser enviado e qual intervalo mínimo entre CS é aceito? O que ocorre com read pendente/novo request? | Bloqueia SPI bit a bit; não inferir resposta imediata |
| P15 | O segmento CFB exigido é 128 bits? Se menor, como se divide o bloco e atualiza o registrador de feedback? | H: CFB-128 apenas como possibilidade |
| P16 | CTR usa o valor inicial antes do primeiro incremento? Incrementa módulo 2^64 ou sinaliza overflow? Como o IP de referência trata carry HI/LO? | Preservar R: IV xor zero_extend_128(counter64), nunca concatenação |
| P17 | Qual comportamento de DECRYPT é esperado em CFB/OFB/CTR e qual ciphertext alimenta o feedback CFB no decrypt? | Proposta: primitiva encrypt nos dois sentidos; validar compatibilidade |
| P18 | Quantas bordas decorrem entre endereço e dado de leitura da RAM? Qual read-during-write e o que mem_o_data faz enquanto AES possui a RAM? | Bloqueia cronograma de busca/escrita e scoreboard |
| P19 | Como o ambiente sinaliza/garante ausência de acesso externo, já que wr_en=0 é read? Qual mecanismo de mux de clock e protocolo de handoff são aprovados? | Ownership em idle é R; mecanismo e observabilidade OPEN |
| P20 | Qual faixa/semente reproduzível do lock pseudoaleatório, quantos ciclos de sys_clk liberam reset, e como tratar disable/divisor/relock durante operação? | PLL mock e reset sequencing futuros; sem gating inseguro |
| P21 | Quais requisitos de assert/deassert e primeiro frame com SCLK inicialmente parado? Há clocks de preparação ou reset de framing aprovado? | Banco não depende de SCLK; serializador ainda precisa recuperação correta |
| P22 | Qual intervalo mínimo entre frames completos e CS? O toggle usa ack/slot e qual garantia impede sobrescrita ou duas alternâncias antes da captura? | D14 propõe retenção/ack, sem novos pinos oficiais |
| P23 | BLOCKS_DONE deve atualizar durante BUSY em cada bloco? Qual atraso/snapshot coerente de status é aceito e como garantir publicação antes de parar sys_clk? | D15 propõe snapshot reconhecido; sem sincronizar bits individualmente |
| P24 | Quais resets de KEY/IV/COUNTER/NUM_BLOCKS/controles/status, valor VERSION, readback START, política de ERROR e reação a RSV/endereço/RO inválidos? | Não inventar constantes ou comandos CLR |
| P25 | START ocupado, configuração escrita durante BUSY, START sem lock/ownership e escrita de owner/divisor simultânea à conclusão: rejeitar, ignorar ou erro? Qual prioridade? | Captura no START é R; política concorrente e handshake são OPEN |
| P26 | Reset no meio das quatro escritas de um bloco deixa resultado parcial? Qual estado de flags/contagem e procedimento de retomada o ambiente exige? | RAM não reseta; não prometer rollback |
| P27 | Qual IP AES de referência será disponibilizado, tecnologia/PDK, ferramentas/versões, restrições de síntese/CDC/UPF e metas de timing/área/energia/MTBF? Como se registra o aceite humano? | Nenhuma métrica física ou aprovação presumida |

Apresentação ao parceiro, respostas oficiais e defesa/aprovação do instrutor
continuam pendentes no [checklist da retomada](../reports/semana_02_retomada.md).
SPI/clock/ownership não impedem os testes puros do datapath da Semana 3.

## Histórico preservado — Semana 1 e proposta v1.0

Atualização: 09/10/2026. A seção inicial preserva o diagnóstico da Semana 1. A tabela de evolução ao final distingue propostas da Semana 2 de requisitos aprovados; não considerar as hipóteses como respostas do instrutor.

## Confirmado na Semana 1

O objetivo final é estudar e desenvolver um acelerador AES com SPI e técnicas de baixo consumo. Nesta entrega há somente estudo, organização e validação do toolchain com uma XOR. O FIPS 197 é normativo para o algoritmo AES; não define a interface SPI nem a microarquitetura deste IP.

Não foi fornecida uma especificação funcional do acelerador. Os itens abaixo são questões para a próxima etapa, sem valores presumidos.

| ID | Decisão pendente | Alternativas e trade-offs | Evidência necessária para decidir |
|---|---|---|---|
| P01 | Tamanhos de chave suportados | 128 reduz a complexidade inicial; 192/256 ou suporte múltiplo ampliam o escopo e a verificação | Requisito funcional do instrutor |
| P02 | Cifragem e decifragem | Só cifragem exige menos funções; ambas podem compartilhar recursos, com mais controle | Operações exigidas e uso do núcleo |
| P03 | Modo SPI | Modo fixo simplifica; modos configuráveis aumentam interoperabilidade e testes | CPOL/CPHA do controlador externo |
| P04 | Frequências e temporização | Mais desempenho pode custar área e energia; SCLK e clock interno podem não ter relação | Frequências, duty cycle, setup/hold, latência e vazão exigidos |
| P05 | Protocolo e mapa de registradores | Registradores facilitam controle; FIFO/comandos podem favorecer fluxos de dados | Endereços, tamanhos, ordem de bits/bytes, CS, status, erros, acesso durante busy |
| P06 | Reset | Síncrono facilita análise temporal; assíncrono permite asserção sem clock, mas a liberação exige cuidado | Polaridade, duração, domínios, valores e comportamento com SCLK parado |
| P07 | Arquitetura AES | Iterativa reutiliza recursos; desenrolada replica rodadas; pipeline aumenta vazão com registradores | Tecnologia, área, latência, vazão e potência |
| P08 | Key Expansion | Pré-calcular/armazenar evita recalcular; gerar durante a operação poupa armazenamento, mas acopla controle | Troca de chaves, recursos, operações e desempenho |
| P09 | CDC | Handshake favorece transferências ocasionais; FIFO assíncrona absorve fluxo; sobreamostragem exige relação temporal comprovada | Domínios, largura de dados, ritmo, pausas de SCLK e taxa aceitável de falha |
| P10 | S-box | Tabela/ROM é direta; lógica booleana ou campos compostos podem mudar área/atraso; compartilhamento aumenta ciclos | FPGA/ASIC, bibliotecas, síntese, timing e atividade |
| P11 | Baixo consumo | Clock enable reduz atividade em certas estruturas; clock gating e power gating exigem suporte físico e controle | Metas, cenários de atividade, biblioteca, isolamento/retenção e ferramentas |
| P12 | Ferramentas oficiais e tecnologia | Fluxo aberto permite estudo local; fluxo do curso pode exigir outra sintaxe, biblioteca e licenças | Versões, PDK/FPGA e critérios do instrutor |
| P13 | Modos de operação criptográficos | AES de bloco é uma primitiva; CBC/CTR/GCM etc. trazem requisitos adicionais | Escopo funcional; nenhum modo é acrescentado nesta entrega |

AES-128 é apenas referência didática. A polaridade ativa baixa indicada por `CS_N` não define a polaridade do reset. Nenhum destes itens possui implementação RTL nesta semana.

Fonte normativa: [NIST FIPS 197-upd1](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf), seções 3 a 6. Os trade-offs são análise de engenharia para discussão, não requisitos extraídos do padrão.

## Evolução na Semana 2 — baseline proposta, sem aceite registrado

Não foi recebida especificação funcional adicional nesta entrega. As escolhas abaixo permitem discutir um contrato concreto e preparar a verificação, mantendo explícita a confirmação que falta. Detalhes na [arquitetura v1.0](../architecture/arquitetura_v1.0.md) e nos [ADRs](../architecture/decisoes_semana_02.md).

**AES-128 é adotado como baseline arquitetural provisório para permitir o desenvolvimento, sujeito à confirmação da especificação funcional do instrutor.**

| ID preservado | Avanço nesta semana | O que ainda falta / pergunta ao instrutor |
|---|---|---|
| P01 | H: AES-128 como baseline provisório; D02 | Confirmar tamanhos de chave exigidos; 192/256 alteram interface/expansão/rodadas |
| P02 | H: somente cifragem, baseline provisório; D02 | Decifragem faz parte do IP? Pode exigir revisão de funções e schedule |
| P03 | D: SPI modo 0 como baseline provisório, MSB primeiro; D11 | Confirmar CPOL/CPHA do mestre com o instrutor; não é requisito oficial |
| P04 | D: clocks independentes; 11 ciclos de cálculo E0–E11, captura em E12, quatro estados da FSM; D01/D06 | Frequências, duty cycle, pinos, latência e throughput; DONE SPI tem latência variável |
| P05 | D: banco SPI 32 bits, mapa e frame de 48 clocks, máscaras e erros; D03/D09–D12 | Aprovar contrato do mestre/driver e readback de KEY |
| P06 | D provisória: rst_n ativo baixo, assert assíncrono/deassert local, reset comum; D07 | Pergunta obrigatória: quem gera SCLK para liberar reset? Se não houver clocks com CS_N alto, qual alternativa/recuperação? Confirmar polaridade, duração e resets separados |
| P07 | D: iterativa de 128 bits, uma rodada/ciclo; D01 | Aprovação e adequação às metas físicas quando informadas |
| P08 | D provisória: gerar round key adiantada por rodada; D04 | Confirmar com instrutor; avaliar troca/reuso de chave e decifragem; validar por síntese/STA |
| P09 | D: banco congelado + req/ack_done de quatro fases; D08 | Aprovar contrato pausável; definir MTBF e validar implementação CDC/RDC/STA posteriormente |
| P10 | H arquitetural / D provisória: 16 + 4 S-boxes combinacionais, preferência por tabela; D05 | Confirmar restrições de recursos; validar por síntese/STA/atividade na tecnologia-alvo; comparar compartilhamento; não demonstrado ótimo |
| P11 | D: reservar enables/isolamento como oportunidades; nenhuma economia alegada | Metas e cenários de potência/energia; domínios de alimentação, retenção e UPF |
| P12 | Fluxo aberto da Semana 1 preservado | Ferramentas oficiais e PDK/FPGA continuam a informar |
| P13 | H: primitiva de bloco sem modo adicional; D02 | Confirmar necessidade de modo, padding, nonce e autenticação; não implementar por inferência |

H = hipótese funcional ou arquitetural; D = decisão arquitetural provisória. AES-128, somente cifragem, SPI modo 0, reset ativo baixo, 16 + 4 S-boxes e estratégia adiantada de Key Expansion não são requisitos oficiais confirmados. P01/P02/P03/P05/P06/P13 precisam de confirmação de escopo/integração para o aceite; P04/P11/P12 exigem que o instrutor esclareça os critérios físicos aplicáveis nesta fase. Parâmetros finais de síntese podem ser detalhados depois, sem fingir que já foram atendidos. A dependência de SCLK na liberação de reset permanece risco alto aberto, e os quatro períodos sugeridos só são viáveis se o mestre os fornecer.

Pendências de processo da entrega: apresentação e revisão com o verificador, defesa e aprovação do instrutor. O [registro do parceiro](../reports/semana_02_verificador.md) deve ser preenchido somente após a atividade ocorrer. A Semana 2 permanece aberta no backlog.
