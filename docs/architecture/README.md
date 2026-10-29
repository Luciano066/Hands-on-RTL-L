# Arquitetura — MiniSoC AES

Contrato vigente: [arquitetura v1.1](arquitetura_v1.1.md), revisada em
29/10/2026 após leitura do Block Guide v1.0.0. **Semana 2 ainda sem aceite.**

- [ADRs: decisões e supersessão](decisoes_semana_02.md).
- [Retomada, auditoria e apresentação](../reports/semana_02_retomada.md).
- [Perguntas OPEN e evolução das pendências](../spec/pendencias.md).
- [Implementação e testes do datapath — Semana 3](../reports/semana_03.md).
- [Contrato interno de expansão/core — Semana 4](aes_core_semana_04.md).
- [Resultados e auditoria da Semana 4](../reports/semana_04.md).

A [v1.0](arquitetura_v1.0.md), [diagnóstico antigo](../reports/semana_02_diagnostico.md),
[defesa antiga](../reports/semana_02_defesa.md) e [pacote antigo de DV](../reports/semana_02_verificador.md)
documentam a proposta elaborada sem especificação. Não usar seus contratos
SPI/mapa/clocks como implementação atual. A v1.0 foi preservada integralmente.

Existe RTL de XOR, rodada AES forward/inverse, Key Expansion e core sequencial
de bloco único. SPI, RAM, PLL, modos e engine/topo integrados estão planejados;
apresentação ao parceiro e aceite do instrutor permanecem pendentes. O arquivo
v1.1 foi preservado; o contrato da Semana 4 é um complemento de implementação.
