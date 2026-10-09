# Arquitetura — Semana 2

Nenhuma arquitetura do acelerador foi congelada na Semana 1. O único circuito implementado é `rtl/smoke_top.sv`, uma XOR sem clock e sem reset.

Na Semana 2 foi preparada uma baseline provisória: AES-128 e somente cifragem são hipóteses funcionais; SPI modo 0 é baseline provisório; reset ativo baixo e expansão adiantada são decisões arquiteturais provisórias; 16 + 4 S-boxes são hipótese a validar por síntese. Nenhuma dessas escolhas é requisito oficial confirmado. O contrato propõe núcleo iterativo, banco SPI de 32 bits e handshake de quatro fases.

- [Documento de arquitetura v1.0](arquitetura_v1.0.md): diagrama, interfaces, ciclos, CDC/reset, mapa, protocolo, comparações e riscos.
- [Registro de decisões](decisoes_semana_02.md): 12 ADRs com justificativas e impactos.
- [Diagnóstico anterior às edições](../reports/semana_02_diagnostico.md).
- [Defesa da Semana 2](../reports/semana_02_defesa.md): apresentação curta e 100 perguntas/respostas.
- [Pacote para o verificador](../reports/semana_02_verificador.md): contratos, matriz de testes futuros e registro de revisão.
- [Pendências funcionais](../spec/pendencias.md): histórico P01–P13 e situação atual.

Não há RTL funcional novo. A Semana 2 permanece aberta para confirmação de requisitos, revisão com o parceiro e aprovação do instrutor. Os relatórios da Semana 1 continuam sendo o registro histórico do estudo e da validação do ambiente.
