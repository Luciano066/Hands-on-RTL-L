# Arquitetura: preparação

Nenhuma arquitetura do acelerador foi congelada na Semana 1. O único circuito implementado é `rtl/smoke_top.sv`, uma XOR sem clock e sem reset.

Uma hipótese para discussão futura é: interface SPI recebe comandos e dados, armazenamento/controlador mantém operandos e status, núcleo AES processa o bloco. O retorno disponibiliza resultado e conclusão ao controlador externo. A localização do banco de registradores e das travessias de clock depende dos domínios escolhidos; um banco de registradores, por si só, não resolve CDC.

Na próxima etapa, produzir diagrama de blocos, interfaces, representação RTL do State, sequência de operações e análise dos cruzamentos após resolver as [pendências funcionais](../spec/pendencias.md). As alternativas e seus custos estão no [roteiro de defesa](../reports/semana_01_defesa.md).
