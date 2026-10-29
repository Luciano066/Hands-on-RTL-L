# Retomada e revisão de conformidade — Semana 2

Data: 29/10/2026. **Semana 2 permanece em revisão, sem aceite humano.**

## Diagnóstico antes das edições

Base local `main`, HEAD `faaf745`, remoto `Luciano066/Hands-on-RTL-L`.
Árvore inicialmente limpa. Histórico: `03bd559` (Semana 1), `de477dd`
(merge preservando README), `faaf745` (revisão documental da Semana 2).
Tags existentes: `w01-v1.0`, `w02-architecture-draft`, `w02-architecture-v1.0`.
Nenhuma tag representa aprovação acadêmica registrada.

Foram conferidos README, BACKLOG, Makefile, arquitetura/ADRs, pendências,
relatórios da Semana 2, RTL/TB e scripts. Havia somente `smoke_top.sv`
com XOR e quatro casos autochecking; nenhum engine AES, SPI, RAM ou PLL.
O smoke foi executado novamente antes das alterações: exit 0, sem warnings.

O plano de retomada foi revisado antes da execução: seus apontamentos foram tratados como
itens a verificar, sem substituir a fonte oficial. Block Guide v1.0.0 local
lido integralmente (15 páginas), com inspeção visual do diagrama da p. 4;
revisão técnica local lida integralmente após ser disponibilizada pelo usuário.
A revisão é interpretação proposta. Ambos permanecem fora do Git.
A extração pypdf reportou avisos de offsets de objetos, mas recuperou as 15
páginas; renderização local permitiu conferir a figura arquitetural. Isso
não é um warning do RTL e não implica alteração do PDF.

Foi criada uma branch dedicada à revisão arquitetural v1.1, sem alterar histórico de main.
Hashes prévios de onze arquivos preservados foram guardados em
`build/retomada_baseline.json` (artefato ignorado): arquitetura v1.0,
RTL/TB XOR, quatro scripts existentes e quatro relatórios da Semana 1.

## Revisão do plano e execução

O plano foi mantido em três partes: auditoria, correção arquitetural e
datapath da Semana 3. Ajustes concretos: separar rodada combinacional do
controlador futuro; fornecer round keys públicas no TB sem implementar
Key Expansion; manter as ambiguidades de integração como OPEN. Não antecipar
o SoC inteiro é adequado ao marco e evita fixar silenciosamente os pontos abertos.

| Divergência encontrada | Correção documental na v1.1 |
|---|---|
| Cifragem de um bloco apenas | Cipher/inverse, seis modos e 1..256 blocos |
| Entrada/saída de blocos por SPI | Payload na RAM via MEMORY DATA |
| Frame próprio de 48 bits e endereço em bytes | 40 bits, endereço de seis bits de registrador, read em duas transações |
| VALID_MASK e comandos CLR próprios | Mapa do guia, sem registradores adicionais |
| Banco em SCLK, sistema com dois clocks | Banco em clk always-on, PLL/sys_clk, SCLK serial e mem_clk externo |
| RAM/PLL ausentes | Planejamento dos módulos, ownership e reset sem apagar RAM |
| Expansão adiantada só forward | Reavaliada para K0..K10 e uso inverso |
| Latência antiga tratada como contrato | E0–E12 restrito ao histórico; sem promessa de latência MiniSoC |

O datapath e testes estão descritos no [relatório da Semana 3](semana_03.md).
As escolhas D13–D19 da [arquitetura](../architecture/arquitetura_v1.1.md)
não são requisitos impostos pelo guia. As equações de modos são propostas
de implementação; CFB, contador e handoff continuam sujeitos às perguntas OPEN.

## Material para apresentar ao parceiro de DV

Roteiro de aproximadamente quinze minutos, a ser realizado pelo estudante:

1. Mostrar diagnóstico, fontes e status de aceite; esclarecer o limite do smoke XOR.
2. Percorrer o diagrama v1.1 e os quatro grupos de portas do topo.
3. Conferir SPI de 40 bits, endereços de registrador e read em dois frames.
4. Desenhar clk always-on, sys_clk após lock, SCLK e mem_clk; explicar evento/toggle.
5. Percorrer leitura/processamento/escrita de quatro palavras in-place e feedback decrypt.
6. Demonstrar os alvos do datapath e comparar um estado intermediário oficial.
7. Registrar respostas às perguntas P14–P27, divergências e responsáveis.

Perguntas essenciais de arguição: por que toggle precisa de retenção/ack?
Por que wr_en=0 não prova idle? Por que RAM não pode zerar no reset?
Por que inverse usa chaves reversas sem transformação neste datapath?
Por que CFB/OFB/CTR usam a primitiva encrypt? Por que CTR usa XOR com IV?
O que os oito KATs demonstram e quais módulos ainda não existem?

## Checklist de revisão e critérios de aceite

- [x] Conferir fontes completas e estado real da base antes de editar RTL/documentação.
- [x] Preservar v1.0 e histórico da Semana 1; criar revisão v1.1 e branch própria.
- [x] Documentar portas, clocks/reset, CDC, RAM, mapa, modos e interface do datapath.
- [x] Separar R/D/H/P e formular perguntas verificáveis em P14–P27.
- [x] Preparar testes autochecking e registrar evidências da Semana 3.
- [ ] Apresentar v1.1 ao parceiro e conferir portas, mapa, empacotamento e fronteiras CDC.
- [ ] Registrar concordâncias/divergências reais do parceiro com revisão/commit e data.
- [ ] Obter respostas do instrutor para as ambiguidades que bloqueiam SPI/RAM/PLL.
- [ ] Realizar defesa e registrar aceite ou correções exigidas pelo instrutor.
- [ ] Incorporar correções e encerrar Semana 2 somente com evidência desse aceite.

| Registro humano | Situação |
|---|---|
| Parceiro, data e material efetivamente apresentado | Pendente |
| Contratos aceitos/divergências e responsáveis | Pendente |
| Respostas oficiais às pendências | Não recebidas nesta execução |
| Defesa e decisão do instrutor | Pendente |

## Autoauditoria e limites

Novos arquivos principais: arquitetura v1.1, este relatório, relatório Semana 3,
package/RTL de datapath, TB, origem de vetores e scripts de execução AES.
Atualizados: README, BACKLOG, índice arquitetural, ADRs, pendências,
avisos de supersessão nos antigos materiais de defesa/revisão, Makefile,
README de síntese e exclusões dos nomes dos anexos confidenciais em .gitignore.
A v1.0 permanece íntegra; material antigo segue acessível como histórico.

Autoauditoria executada: hashes SHA256 dos onze arquivos preservados iguais,
19 arquivos Markdown lidos, 80 links relativos válidos, P14–P27 presentes e
zero fontes confidenciais nos arquivos entregáveis. `git diff --check` passou.
Resumo local: `build/final_audit.json`. O Mermaid foi inspecionado como fonte;
não foi executado renderizador oficial nesta revisão.

Não há envio a terceiros, push, merge ou tag nova. Os documentos confidenciais
não foram copiados para o projeto. Renderizações locais e dependências de leitura
ficam somente em build, ignorado pelo Git. Testes AES não validam SPI/CDC/RAM/PLL,
nem aprovação humana, síntese mapeada, timing de 2 GHz, potência ou MTBF.
Houve somente síntese genérica do datapath, documentada na Semana 3.

Semana 4: implementar e testar Key Expansion com K0..K10 oficiais, escolher
armazenamento/ordem inversa, adicionar registradores/controle ao datapath e
validar cipher/inverse sequenciais antes do controlador de modos/memória.
