# Diagnóstico anterior às alterações — Semana 2

Data: 09/10/2026. Inspeção concluída antes da primeira edição desta entrega.

## 1. Base encontrada

- HEAD: `de477dd`, com a tag `w01-v1.0`; `git status --short` inicialmente vazio.
- A Semana 1 está concluída, validada e versionada. Seu circuito é exclusivamente uma XOR combinacional, acompanhada de quatro casos autochecking.
- Makefile e scripts encadeiam lint, compilação e simulação. Há ferramentas portáteis em `.tools/` e artefatos ignorados em `build/`.
- Não há implementação de AES, SPI, registradores do acelerador, CDC, síntese, formal ou UPF.
- O README descrevia Git ainda sem commit/remoto, enquanto o histórico atual já contém commits e a tag. Essa descrição será atualizada; os relatórios históricos da Semana 1 serão preservados.

## 2. Material lido

Foram lidos os 20 arquivos versionados: README, BACKLOG, Makefile, `.gitignore`, `.gitattributes`, os quatro relatórios da Semana 1, `docs/spec/pendencias.md`, `docs/architecture/README.md`, os README de formal/syn/upf, RTL XOR, testbench e os quatro scripts. Também foi lido integralmente o pedido da Semana 2 anexado pelo estudante.

Foram consultados o [FIPS 197-upd1](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf), especialmente seções 3.4, 5.1 e 5.2, e a referência [Analog Devices sobre SPI](https://www.analog.com/en/resources/analog-dialogue/articles/introduction-to-spi-interface.html). As fontes definem algoritmo e fundamentos da interface, respectivamente; não aprovam a microarquitetura deste projeto.

## 3. O que já estava confirmado

| Item | Evidência / limite |
|---|---|
| Objetivo final AES + SPI + baixo consumo | README, relatório e backlog da Semana 1 |
| Algoritmo conforme FIPS 197 | Referência normativa; não impõe microarquitetura |
| Organização dos bytes do State por colunas | Relação normativa já estudada; fatias RTL ainda não fixadas |
| Separação RTL/testbench e fluxo Make | Validação executada na Semana 1 |
| Ambiente aberto Windows identificado | Versões e hashes registrados; ferramentas oficiais do curso ainda pendentes |
| Semana 2 dedicada à arquitetura | Pedido atual: dez entregas, aceite pela defesa aprovada pelo instrutor |
| Preservação da base validada | Não implementar as transformações nem SPI funcional nesta entrega |

AES-128 era **exemplo didático**, não requisito oficial. Iteratividade, banco de registradores e handshake eram **alternativas estudadas**, não escolhas anteriores já aprovadas.

## 4. O que estava aberto e precisa avançar

| IDs originais | Situação inicial | Ação necessária na Semana 2 |
|---|---|---|
| P01, P02, P13 | Variante, cifragem/decifragem e modos não especificados | Propor baseline limitado e solicitar confirmação funcional |
| P03, P05 | SPI e mapa inexistentes | Fixar proposta de modo, transações, ordem de bytes, mapa e erros |
| P04 | Sem frequência, duty cycle, setup/hold ou metas de vazão | Separar clocks; expressar ciclos e restrições simbólicas, sem inventar MHz |
| P06 | Reset sem polaridade ou protocolo | Definir proposta de assert/deassert e tratamento de SCLK parado |
| P07 | Microarquitetura aberta | Comparar e selecionar arquitetura, datapath, FSM e latência |
| P08, P10 | Key Expansion e S-box abertas | Escolher organização inicial compatível com ciclos e recursos |
| P09 | CDC aberto | Definir transferência atômica nos dois sentidos e fechamento do handshake |
| P11, P12 | Potência e tecnologia sem metas/ambiente oficial | Preservar pendências e prever pontos de medição/integração |

Interfaces, representação dos dados, comportamento START/BUSY/DONE, completude dos operandos e regras de reset precisam estar suficientemente definidos para o verificador escrever testes. Já frequências absolutas, MTBF e métricas físicas dependem de informações do curso e não podem ser declaradas atendidas nesta semana.

## 5. Direção adotada após o diagnóstico

Preparar uma arquitetura v1.0 **proposta para defesa**, com decisões de engenharia rastreáveis e hipóteses explícitas. AES-128 somente cifragem, iterativo, uma rodada por ciclo, será avaliado como baseline. Os detalhes e justificativas serão registrados no [documento de arquitetura](../architecture/arquitetura_v1.0.md) e nos [ADRs](../architecture/decisoes_semana_02.md).

A mudança de “alternativa em estudo” na Semana 1 para “baseline proposto” na Semana 2 é intencional: permite discutir um contrato completo sem fabricar uma aprovação do professor. A entrega documental não significa que a arquitetura foi implementada ou aprovada. A apresentação/revisão com o parceiro e o aceite do instrutor permanecem ações humanas pendentes.
