> **Histórico de 09/10/2026, contrato v1.0 superado.** Em 29/10/2026,
> a leitura do Block Guide motivou a [arquitetura v1.1](../architecture/arquitetura_v1.1.md).
> Use o [relatório/roteiro de retomada](semana_02_retomada.md) para a defesa atual
> e o [relatório da Semana 3](semana_03.md) para os testes AES. Semana 2 segue
> sem apresentação/aceite registrados. As afirmações abaixo descrevem a entrega antiga.

# Entrega documental e revisão — Semana 2

Data: 09/10/2026. Base inicial: `de477dd`, tag `w01-v1.0`, árvore limpa antes das edições.

**Situação: arquitetura preparada para defesa; Semana 2 ainda não concluída.** Faltam confirmação dos requisitos essenciais, apresentação/revisão com o verificador e aprovação do instrutor. Não houve implementação funcional AES/SPI nem envio a terceiros.

## 1. Resultado preparado

AES-128 e somente cifragem são hipóteses funcionais da baseline provisória, com datapath iterativo de 128 bits e uma rodada por ciclo. Expansão adiantada é decisão arquitetural provisória; 16 + 4 S-boxes são hipótese arquitetural a validar por síntese, STA e atividade. Nenhuma delas é requisito oficial confirmado ou solução comprovadamente ótima.

SPI modo 0 é **baseline provisório**, pendente da confirmação do instrutor e do mestre. O mapa proposto usa palavras de 32 bits e frames de 48 clocks; banco em SCLK, máscaras de completude e bloqueio durante BUSY. Handshake de quatro fases com dados estáveis conecta ao sistema; as onze etapas agora distinguem origem/destino em ambos os sentidos. Reset comum ativo baixo é decisão arquitetural provisória; sua liberação local pode ficar bloqueada sem SCLK, risco ainda aberto.

**Latência revisada:** aceitação do start local e carga em E0; onze ciclos internos de cálculo até publicação de done/data_out após E11; captura pelo adaptador em E12. Há doze bordas E0–E11 inclusive e **quatro estados distintos de FSM**, não doze estados. A frase “11 períodos após aceitar start local” permanece correta sob esse escalonamento; não se aplica a CONTROL.START → STATUS.DONE, cuja latência inclui SPI/CDC e é variável.

Essas são escolhas para discussão, não requisitos oficiais extraídos do FIPS. O fundamento e os trade-offs estão na [arquitetura v1.0](../architecture/arquitetura_v1.0.md). A frase de baseline provisório solicitada aparece ali, nos ADRs e nas pendências.

## 2. Arquivos criados e modificados

| Arquivo | Ação | Conteúdo |
|---|---|---|
| docs/architecture/arquitetura_v1.0.md | Criado | Contrato completo, dois diagramas Mermaid, tabelas de interface/mapa/ciclos, comparações, 20 riscos e perguntas ao professor |
| docs/architecture/decisoes_semana_02.md | Criado | 12 decisões em formato ADR, com todos os oito campos solicitados |
| docs/reports/semana_02_diagnostico.md | Criado | Estado e decisões antes das alterações, leitura da Semana 1 e plano de evolução |
| docs/reports/semana_02_defesa.md | Criado | Roteiro de cinco minutos, 100 perguntas e respostas, plano de estudo |
| docs/reports/semana_02_verificador.md | Criado | Apresentação de 15 minutos, contratos, 39 verificações futuras e registro de revisão pendente |
| docs/reports/semana_02.md | Criado | Este relatório de entrega, verificações e limites |
| BACKLOG.md | Modificado | Semana 1 concluída; Semana 2 com material preparado, decisões, perguntas e aceite pendente |
| README.md | Modificado | Navegação da Semana 2, baseline proposta e correção do estado histórico do Git |
| docs/architecture/README.md | Modificado | Índice da nova arquitetura e seu status |
| docs/spec/pendencias.md | Modificado | Histórico P01–P13 preservado e evolução das propostas acrescentada |

Nenhuma modificação em RTL, TB, Makefile, scripts, `.gitattributes`, `.gitignore`, relatórios da Semana 1 ou README de formal/syn/upf. Não foram criados stubs porque as tabelas e o pseudocódigo já fixam os contratos sem confundir proposta com implementação.

Na revisão solicitada após a primeira redação, foram alterados **nove desses documentos**: todos os itens da tabela exceto `semana_02_diagnostico.md`, que preserva o diagnóstico anterior às primeiras edições. “Criado” na tabela refere-se à entrega acumulada da Semana 2; os arquivos novos continuam sem commit.

### Principais correções: antes → depois

| Tema | Antes | Depois desta revisão |
|---|---|---|
| Status das escolhas | Proposta indicada globalmente; alguns trechos apenas diziam “modo 0” ou “escolhido” | Rótulos explícitos: hipóteses AES-128/cifragem, baseline SPI modo 0, decisões provisórias de reset/expansão, hipótese 16 + 4 a validar por síntese |
| Latência / FSM | 11 períodos e 12 bordas, sem quadro separado de conceitos | Tabela E0–E12 com captura final/consumo; 11 ciclos de cálculo, publicação após E11, consumo E12 e quatro estados distintos |
| S-box | Contagem 16 + 4 com trade-offs gerais | Justificativa por byte/SubWord, custos e caminhos concorrentes, alternativas de compartilhamento e efeito em throughput |
| CDC | Seis passos agrupados | Onze etapas, origem/destino de cada barramento, ACK retardado até resultado, tabela de controles e diagrama de sequência |
| Reset pausado | Quatro clocks sugeridos como contrato de partida | Condição provisória dependente do mestre; risco alto aberto, alternativas comparadas e pergunta obrigatória ao professor |
| DONE | Limpeza descrita sem comparar as três políticas | done interno, DONE sticky e BUSY transacional separados; comparação de novo START, W1C e leitura; combinação provisória START aceito + CONTROL.CLR_DONE |
| Máscaras / mapa | Máscaras genéricas e mapa de endereços | KEY_VALID_MASK/DATA_IN_VALID_MASK explícitas, tabela de eventos/exemplo; natureza de cada registro e STATUS local esclarecidos |
| Riscos / defesa | 16 riscos, 96 perguntas | 20 riscos, 100 perguntas; separação de mudança de variante, decifragem, modo SPI, frequências e tecnologia |

## 3. Validação realmente executada

Comando na raiz do projeto:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_smoke.ps1
```

Resultado da nova execução após esta revisão, em 09/10/2026: exit code 0. Verilator executou lint; Icarus recompilou RTL + TB; vvp executou os quatro casos da XOR. Não houve warnings no smoke. Trecho da saída:

```text
verilator_bin --lint-only -Wall --top-module smoke_top rtl/smoke_top.sv
iverilog -g2012 -Wall -s tb_smoke_top -o build/smoke.vvp rtl/smoke_top.sv tb/tb_smoke_top.sv
vvp build/smoke.vvp
SMOKE TEST PASS
tb/tb_smoke_top.sv:35: $finish called at 4000 (1ps)
Semana 1: fluxo minimo concluido com sucesso.
```

Verilator reportou `5.053 devel rev v5.052-119-g014c9820d (mod)`, consistente com a base. Não foi reinstalado toolchain, alterado PATH global ou alterada política global. `build/smoke.vvp` foi regenerado como artefato local ignorado; os ensaios negativos extensivos da Semana 1 não precisaram ser repetidos porque seus fontes e fluxo foram preservados.

Foi conferida a ausência de diferenças nos arquivos executáveis e históricos preservados via `git diff --exit-code`, com retorno zero. `git diff --check` não apontou erros de whitespace.

Os dois diagramas Mermaid foram processados pelo renderizador local compatível `grok-mermaid 0.2.2`, já disponível no ambiente, sem instalação ou download. Ambos produziram diagramas textuais sem warnings; a sequência foi inspecionada. Isso verifica a sintaxe suportada por esse renderizador, sem afirmar renderização gráfica no motor oficial do Mermaid. Artefatos de conferência ficam apenas em `build/semana_02_revisao/`, ignorado pelo Git.

A conferência estrutural retornou `DOCUMENT REVIEW CHECK PASS`: 14 arquivos Markdown UTF-8, 55 links relativos válidos, 100 perguntas sequenciais, 12 ADRs com os oito campos, 20 riscos, 39 cenários futuros, 13 linhas E0–E12 e 11 etapas CDC. Os 15 endereços continuam iguais à redação anterior, alinhados e sem sobreposição (60 bytes mapeados); acessos RO/RW, larguras, reset e domínio também foram preservados. Máscaras e tipo de armazenamento foram explicitados documentalmente, sem implementação.

Os hashes SHA256 dos **16 arquivos de fontes/configuração/relatórios preservados da Semana 1** permanecem idênticos ao início desta revisão; `git diff --exit-code` desses arquivos também retornou zero. A checagem identificou nove documentos efetivamente alterados, mantendo o diagnóstico intacto. O resumo local está em `build/semana_02_revisao/conferencia_documental.json`.

A revisão semântica conferiu as seis escolhas provisórias nos documentos atuais e comparou os contratos de latência, CDC, reset, máscaras e flags. Nenhuma hipótese foi promovida a requisito confirmado. O quadro “antes → depois” e a seção histórica da Semana 1 registram estados anteriores como histórico, não como contratos atuais. Não foi executado modelo funcional do acelerador.

**Limite da evidência:** o PASS continua validando somente a XOR e o ambiente. Não houve teste funcional AES, teste de protocolo SPI/CDC, prova formal, síntese, fechamento de timing, avaliação de MTBF ou medição de potência. O Mermaid é fonte textual para renderizadores compatíveis; não é desenho de uma netlist implementada.

## 4. Revisão crítica e próximos responsáveis

A [seção 15 da arquitetura](../architecture/arquitetura_v1.0.md) registra 20 riscos com níveis e mitigação. Inclui explicitamente mudança AES-128→192/256, exigência de decifragem, alteração do modo SPI, timing de Round Logic/Key Expansion, custo de 20 S-boxes, coerência física do CDC, reset SPI sem SCLK, frequências desconhecidas e ausência de estimativas com tecnologia/PDK. Há também limitações deliberadas: um único slot, nenhuma escrita de operandos durante BUSY, ausência de códigos de erro detalhados e chave legível.

Para estudar: desenhar o fluxo, repetir E0–E12 e os quatro estados, justificar 16 + 4 S-boxes e suas alternativas, percorrer o handshake com SCLK parado, explicar máscaras e done/DONE/BUSY, comparar área/throughput/energia. As 100 respostas servem de roteiro, não de substituto para compreender os contratos.

Levar ao professor: variantes/operações/modos; mestre SPI e mapa; reset e, **obrigatoriamente, quem fornece SCLK para liberar reset e qual alternativa usar sem clocks de inicialização**; frequências/pinos; metas de área/energia/MTBF; tecnologia/ferramentas; hipótese de 20 S-boxes/expansão adiantada; proteção da chave; forma de aceite. O estudante e o parceiro devem registrar a apresentação efetiva no [pacote de revisão](semana_02_verificador.md).

## 5. Versionamento sugerido

Mensagem de commit: `docs: prepara arquitetura v1.0 e defesa da Semana 2`.

Tag sugerida: `w02-architecture-v1.0`, identificando esta revisão documental. Sua anotação deve informar “proposta para defesa; aceite pendente” se criada antes da aprovação; alternativamente, criar a tag após incorporar o aceite. Não usar a tag como evidência de aprovação que não ocorreu.

Commit, tag e push não foram executados automaticamente. A lista acima delimita os dez arquivos da entrega; conferir `git status --short` antes de versionar.
