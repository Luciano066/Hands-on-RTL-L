# Arquitetura — MiniSoC AES

Contrato vigente: [arquitetura v1.1](arquitetura_v1.1.md), revisada em
29/10/2026 após leitura do Block Guide v1.0.0. **Semana 2 ainda sem aceite.**

- [ADRs: decisões e supersessão](decisoes_semana_02.md).
- [Retomada, auditoria e apresentação](../reports/semana_02_retomada.md).
- [Perguntas OPEN e evolução das pendências](../spec/pendencias.md).
- [Implementação e testes do datapath — Semana 3](../reports/semana_03.md).

A [v1.0](arquitetura_v1.0.md), [diagnóstico antigo](../reports/semana_02_diagnostico.md),
[defesa antiga](../reports/semana_02_defesa.md) e [pacote antigo de DV](../reports/semana_02_verificador.md)
documentam a proposta elaborada sem especificação. Não usar seus contratos
SPI/mapa/clocks como implementação atual. A v1.0 foi preservada integralmente.

Existe RTL de XOR e de rodada AES forward/inverse. SPI, RAM, PLL, Key Expansion,
FSM e topo integrado estão planejados; apresentação ao parceiro e aceite do
instrutor permanecem pendentes.
