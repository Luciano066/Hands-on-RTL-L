# Escopo confirmado e decisões pendentes

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
