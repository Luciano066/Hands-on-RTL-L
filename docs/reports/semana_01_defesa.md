# Defesa técnica — Semana 1

Este roteiro explica decisões realmente tomadas e alternativas estudadas. Nenhuma discussão de arquitetura abaixo equivale a um requisito aprovado. O [relatório de estudo](semana_01.md) apresenta os fundamentos; as [pendências P01–P13](../spec/pendencias.md) delimitam o que depende de especificação.

## 1. Repositório estruturado e raiz única

DECISÃO: mover os sete arquivos da pasta duplicada para a raiz e completar os diretórios previstos; inicializar Git localmente.

MOTIVAÇÃO: tornar inequívocos os caminhos de execução e os lugares de RTL, testes, documentação e futuras etapas físicas.

ALTERNATIVAS: manter uma pasta única com tudo ou adotar vários subprojetos.

TRADE-OFFS: a organização exige convenções, mas facilita revisão, comparação de versões e crescimento. Diretórios ainda sem implementação contêm README que explica seu propósito.

O QUE AINDA NÃO FOI DECIDIDO: hospedagem remota, política de branches e integração contínua. Não houve publicação nem commit automático.

## 2. Automação com Makefile

DECISÃO: usar GNU Make como ponto de entrada e representar dependências entre etapas.

MOTIVAÇÃO: registrar comandos exatos e propagar falhas de forma repetível.

ALTERNATIVAS: script Bash/PowerShell único, CMake ou sistema específico de verificação.

TRADE-OFFS: Make é pequeno e legível, mas depende de ambiente de execução; o Makefile atual usa shell POSIX. No Windows, os scripts ativam ferramentas locais e o shell do Git for Windows.

O QUE AINDA NÃO FOI DECIDIDO: automação de síntese, formal e ferramentas oficiais.

## 3. Um comando e ordem obrigatória

DECISÃO: `make smoke` percorre `check-tools → lint → compile → sim`; `make sim` também constrói seus pré-requisitos.

MOTIVAÇÃO: evitar esquecer uma etapa e garantir que a simulação use o resultado da compilação atual.

ALTERNATIVAS: executar cada ferramenta manualmente ou listar as etapas como pré-requisitos independentes.

TRADE-OFFS: a cadeia serial reduz paralelismo, apropriado porque as etapas dependem umas das outras. Alvos phony recompilam a pequena XOR a cada execução.

O QUE AINDA NÃO FOI DECIDIDO: execução paralela de testes independentes e cache de grandes compilações. Preparar ferramentas é um passo anterior; `make smoke` não instala dependências silenciosamente.

## 4. Smoke test com uma XOR

DECISÃO: preservar o módulo combinacional de dois bits de entrada já existente.

MOTIVAÇÃO: quatro casos bastam para conferir a tabela-verdade binária e exercitar lint, elaboração e simulação.

ALTERNATIVAS: contador com reset, FSM simples ou implementar AES desde o início.

TRADE-OFFS: a simplicidade localiza problemas do ambiente, mas não verifica clocks, reset, SPI ou criptografia. Um contador exigiria convenções adicionais sem necessidade nesta semana.

O QUE AINDA NÃO FOI DECIDIDO: clock e reset do acelerador; a ausência desses sinais no smoke não decide nada sobre o IP futuro.

## 5. Separação de RTL e testbench

DECISÃO: circuito em `rtl/` e estímulos/checks em `tb/`.

MOTIVAÇÃO: distinguir a descrição do hardware do código que o exercita e observa.

ALTERNATIVAS: misturar ambos no mesmo arquivo ou construir um ambiente complexo de verificação.

TRADE-OFFS: arquivos separados exigem uma lista de fontes, mas evitam incluir acidentalmente delays e tarefas de simulação no conjunto de síntese.

O QUE AINDA NÃO FOI DECIDIDO: infraestrutura futura de scoreboard, assertions e cobertura.

## 6. Teste autochecking, temporização e encerramento

DECISÃO: usar resultados explícitos, `!==`, `$fatal(1,...)`, `$finish` e limite de 100 ns.

MOTIVAÇÃO: transformar divergências em falha observável pelo comando e detectar X/Z inesperados. O atraso de 1 ns permite propagar o assign antes da comparação.

ALTERNATIVAS: observar ondas manualmente, usar assertions ou calcular a referência com a mesma expressão do DUT.

TRADE-OFFS: a tabela explícita é adequada à XOR; não escala para AES. Repetir a implementação no modelo de referência poderia repetir também o erro. O watchdog cobre ausência de término com avanço do tempo simulado, não travamento do compilador nem laço infinito de tempo zero.

O QUE AINDA NÃO FOI DECIDIDO: timeouts de parede, cobertura e referência independente das futuras transformações.

## 7. Lint como primeira barreira

DECISÃO: Verilator com `--lint-only -Wall` no RTL e Icarus com `-Wall` na compilação do RTL e TB.

MOTIVAÇÃO: detectar problemas de largura, sinais e construções suspeitas antes da simulação.

ALTERNATIVAS: confiar apenas no compilador ou adotar lint especializado do curso.

TRADE-OFFS: lint pode emitir avisos que exigem interpretação; não prova correção funcional. Avisos do Verilator permanecem fatais por padrão, sem supressão geral. `-Wall` do Icarus não transforma automaticamente todo warning em erro.

O QUE AINDA NÃO FOI DECIDIDO: regras de lint do curso, waivers justificados e análise estática de CDC.

## 8. Lint, compilação, simulação e síntese

DECISÃO: executar e relatar as três primeiras etapas; reservar síntese para depois.

MOTIVAÇÃO: lint analisa o código estaticamente; compilação/elaboração verifica linguagem e hierarquia; simulação executa o modelo com estímulos; síntese converte RTL sintetizável em uma rede lógica, que pode ser mapeada para uma biblioteca.

ALTERNATIVAS: incluir síntese desde já, após escolher ferramenta e tecnologia.

TRADE-OFFS: o escopo atual verifica o ambiente com poucas dependências, mas não produz métricas físicas. Ser sintetizável por construção não significa ter passado por síntese.

O QUE AINDA NÃO FOI DECIDIDO: PDK/FPGA, restrições, bibliotecas, frequência e critérios físicos.

## 9. Verilator e Icarus como referência provisória

DECISÃO: usar ferramentas abertas disponíveis em distribuição portátil e registrar versões.

MOTIVAÇÃO: obter execução local verificável antes de receber o ambiente oficial.

ALTERNATIVAS: simulador comercial, ferramentas de FPGA ou instalação Linux/WSL.

TRADE-OFFS: ferramentas diferentes expõem classes distintas de problema, mas variam em suporte a SystemVerilog, simulação e diagnósticos. O pacote selecionado contém builds de desenvolvimento; fixar o pacote e seu hash torna esta execução identificável, sem prometer adequação industrial.

O QUE AINDA NÃO FOI DECIDIDO: ferramentas finais. Migrar exigirá nova validação, não apenas trocar nomes de executáveis.

## 10. Ambiente Windows local e limpeza restrita

DECISÃO: instalar ferramentas em `.tools/`, ativar PATH apenas na sessão e usar o executável nativo `verilator_bin` para lint com `VERILATOR_ROOT` explícito. Usar GNU Make do MSYS2 com o shell do Git for Windows. `make clean` remove somente `build/smoke.vvp`.

MOTIVAÇÃO: a máquina não possuía make/Verilator/Icarus no PATH nem distribuição WSL; o lançador Perl do Verilator encontrou módulo ausente. O executável nativo atende ao lint usado aqui.

ALTERNATIVAS: instalar WSL e pacotes Linux, completar a instalação Perl ou configurar ferramentas globais.

TRADE-OFFS: o pacote portátil ocupa espaço e a primeira execução precisa de download; evita alterar configuração global. A limpeza restrita deixa diretórios/logs disponíveis, em vez de apagar recursivamente uma variável de caminho.

O QUE AINDA NÃO FOI DECIDIDO: distribuição definitiva para o laboratório. O bootstrap pressupõe Windows x64, Git for Windows, curl e tar compatível com zstd.

## 11. AES-128 como referência de estudo

DECISÃO: usá-lo para exemplos de dez rodadas e onze round keys, sem limitar o IP a ele.

MOTIVAÇÃO: reduzir a quantidade de passos a acompanhar ao estudar o algoritmo.

ALTERNATIVAS: estudar primeiro AES-192/256 ou projetar um núcleo parametrizável.

TRADE-OFFS: menor escopo didático facilita compreensão; suporte múltiplo exige controle e expansão de chave mais abrangentes.

O QUE AINDA NÃO FOI DECIDIDO: variantes suportadas, cifragem/decifragem e modos de operação. Consultar P01, P02 e P13.

## 12. Arquitetura iterativa versus desenrolada

DECISÃO: documentar alternativas, sem implementar ou escolher uma.

MOTIVAÇÃO: o FIPS define resultados, não quantos recursos existem nem quantos ciclos cada rodada usa.

ALTERNATIVAS: reutilizar uma unidade de rodada, serializar por bytes/palavras, desenrolar parcialmente ou replicar todas as rodadas, com ou sem pipeline.

TRADE-OFFS: reutilização tende a reduzir área e aumentar ciclos por bloco; replicação aumenta recursos e pode melhorar vazão. Desenrolar tudo sem pipeline cria um caminho combinacional longo. Pipeline adiciona registradores e pode aceitar novos blocos com maior frequência, sem necessariamente reduzir a latência do primeiro bloco. Menor área não garante menor energia por bloco.

O QUE AINDA NÃO FOI DECIDIDO: largura do datapath, número de estágios, latência, vazão e metas de consumo (P04, P07, P11).

## 13. Armazenar ou gerar round keys

DECISÃO: manter as duas opções em análise.

MOTIVAÇÃO: a chave correta precisa estar disponível no momento de AddRoundKey.

ALTERNATIVAS: pré-expandir e armazenar, gerar durante o processamento ou usar uma estratégia híbrida.

TRADE-OFFS: armazenamento facilita reutilizar a chave entre blocos e acessar chaves em ordem inversa; custa memória e tempo inicial. Geração durante a operação reduz armazenamento, mas pode disputar S-box e exigir recálculo. Decifragem precisa receber as chaves na ordem apropriada.

O QUE AINDA NÃO FOI DECIDIDO: frequência de troca de chave, suporte a decifragem, compartilhamento e capacidade de armazenamento (P08).

## 14. Implementação da S-box

DECISÃO: estudar equivalência funcional entre tabela e cálculo, sem escolher implementação.

MOTIVAÇÃO: a função matemática é fixa, mas área, atraso e consumo dependem da realização física.

ALTERNATIVAS: tabela em case/ROM, lógica booleana otimizada ou inversão em campos compostos seguida de transformação afim; instâncias paralelas ou compartilhadas.

TRADE-OFFS: tabela é direta para conferir; o mapeamento em ROM ou LUT depende da ferramenta/tecnologia. Cálculo pode reduzir ou aumentar custo conforme o mapeamento. Memória síncrona pode adicionar latência. Compartilhar reduz instâncias, mas aumenta ciclos e controle.

O QUE AINDA NÃO FOI DECIDIDO: P10 e requisitos de proteção física. S-box combinacional, por si só, não garante resistência a canais laterais.

## 15. Representação do State

DECISÃO: adotar a correspondência normativa `s[r,c] = in[r+4*c]` como referência documental.

MOTIVAÇÃO: uma transposição acidental pode invalidar ShiftRows, MixColumns e a comparação com vetores.

ALTERNATIVAS: vetor packed, matriz de bytes ou armazenamento serializado, todos com conversão explícita.

TRADE-OFFS: matriz favorece leitura; vetor pode facilitar interfaces; serialização altera controle e número de ciclos. Nenhuma representação física muda a definição matemática.

O QUE AINDA NÃO FOI DECIDIDO: fatias RTL, ordem na interface e mapa de registradores (P05).

## 16. Banco de registradores entre SPI e AES

DECISÃO: tratá-lo como hipótese de interface, sem definir endereços nem implementar banco.

MOTIVAÇÃO: SPI entrega bits/bytes ao longo do tempo; AES precisa de operandos e comando coerentes. Registradores podem guardar chave, entrada, saída, controle e status.

ALTERNATIVAS: FIFO, buffers de comandos ou interface de fluxo.

TRADE-OFFS: registradores facilitam controle por software, mas exigem semântica de escrita parcial, busy e consistência dos operandos. Fluxo pode favorecer vazão e adicionar backpressure. Registradores comuns não resolvem CDC automaticamente.

O QUE AINDA NÃO FOI DECIDIDO: existência/organização final do banco, localização por domínio, protocolo, erros e política de atualização (P05).

## 17. CDC e metastabilidade

DECISÃO: identificar a necessidade provável e adiar a escolha do mecanismo.

MOTIVAÇÃO: se SPI usar SCLK e AES usar clock do sistema sem relação garantida, haverá transferências assíncronas.

ALTERNATIVAS: sincronizador para nível isolado, handshake, FIFO assíncrona ou amostragem SPI pelo clock do sistema com requisitos temporais demonstrados.

TRADE-OFFS: sincronizador acrescenta latência e reduz probabilidade de falha, mas não preserva sozinho pulsos ou barramentos coerentes. Handshake limita ritmo; FIFO custa armazenamento e controle; sobreamostragem exige limites de frequência e temporização.

O QUE AINDA NÃO FOI DECIDIDO: domínios, protocolo, profundidade de sincronização e MTBF requerido (P04, P06, P09).

## 18. SPI, reset e frequência

DECISÃO: estudar os quatro modos SPI e registrar os parâmetros como pendentes.

MOTIVAÇÃO: um modo de exemplo num artigo não define o periférico a construir.

ALTERNATIVAS: modo fixo ou configurável; reset síncrono ou assíncrono, ativo alto ou baixo.

TRADE-OFFS: configurabilidade aumenta cobertura e lógica; modo fixo restringe compatibilidade. Reset assíncrono pode atuar sem clock, mas sua liberação precisa de tratamento por domínio. Frequências maiores podem exigir pipeline e elevar consumo.

O QUE AINDA NÃO FOI DECIDIDO: todos os valores concretos destes parâmetros, inclusive comportamento quando SCLK para.

## 19. Vetores oficiais e verificação progressiva

DECISÃO: planejar testes independentes de transformações, chaves e estados intermediários antes da integração completa.

MOTIVAÇÃO: localizar a primeira divergência e evitar confiar apenas no resultado de ida e volta.

ALTERNATIVAS: conferir só o ciphertext, só decifrar o próprio resultado ou observar ondas.

TRADE-OFFS: estados intermediários demandam mais preparação, mas ajudam a distinguir erros de representação e algoritmo. Uma referência que copia o mesmo RTL pode reproduzir o mesmo erro.

O QUE AINDA NÃO FOI DECIDIDO: conjunto final de testes e cobertura; o smoke desta semana não valida AES nem representa certificação.

## 20. Baixo consumo adiado até haver requisitos e medições

DECISÃO: reservar `upf/` e backlog de avaliação, sem inserir gating no smoke.

MOTIVAÇÃO: técnicas de potência dependem da arquitetura, atividade e tecnologia.

ALTERNATIVAS: clock enable, isolamento de operandos, clock gating com células apropriadas, power gating com isolamento/retenção quando necessário.

TRADE-OFFS: reduzir atividade pode economizar potência dinâmica; gating acrescenta controle e verificação. Desligar alimentação exige avaliar estado retido e tempo de retorno. Potência instantânea e energia por bloco são métricas diferentes.

O QUE AINDA NÃO FOI DECIDIDO: metas, técnicas, domínios, UPF e cenários de medição (P11). Não é possível inferir consumo de silício a partir do PASS de uma XOR.

# Perguntas prováveis da arguição

## Fundamentos

1. **AES é cifra de bloco ou de fluxo?** De bloco, com blocos de 128 bits.
2. **AES é simétrico ou assimétrico?** Simétrico: depende de uma chave secreta compartilhada.
3. **AES-256 possui bloco de 256 bits?** Não; sua chave tem 256 bits e seu bloco tem 128.
4. **Por que o State possui 16 bytes?** Porque 128 bits divididos por oito resultam em 16 bytes.
5. **Como os bytes entram no State?** Por colunas, pela relação `s[r,c] = in[r+4*c]`.
6. **Qual transformação introduz não linearidade no datapath?** SubBytes, por meio da S-box.
7. **O que ShiftRows faz?** Rotaciona as linhas em 0, 1, 2 e 3 bytes para a esquerda na cifragem.
8. **ShiftRows modifica os valores dos bytes?** Não; apenas suas posições.
9. **O que MixColumns faz?** Mistura linearmente os quatro bytes de cada coluna no campo GF(2^8).
10. **O que significa GF(2^8)?** Um campo finito de 256 elementos, representáveis por bytes.
11. **Multiplicar em GF(2^8) é multiplicar inteiros módulo 256?** Não. Usa polinômios binários e redução pelo polinômio especificado no AES.
12. **Por que AddRoundKey usa XOR?** É a combinação definida pelo AES, simples em hardware e reversível com a mesma chave.
13. **XOR sozinho já cifra como AES?** Não; AES combina chave, não linearidade e difusão em várias rodadas.
14. **Quantas rodadas existem no AES-128?** Dez, além da adição de chave inicial.
15. **Quantas round keys são usadas no AES-128?** Onze de 128 bits, contando a inicial.
16. **Por que a última rodada é diferente?** O padrão omite MixColumns; inseri-la altera o ciphertext. A interpretação algébrica de uma transformação linear terminal está no relatório, sem mudar a regra normativa.
17. **O que é Key Expansion?** A derivação determinística de chaves de rodada a partir da chave original.
18. **Key Expansion aumenta a entropia da chave?** Não; todo o material expandido depende da chave inicial.
19. **O que fazem RotWord, SubWord e Rcon?** Rotacionam bytes, aplicam a S-box aos bytes e introduzem constantes na expansão.
20. **AES-192 e AES-256 têm quantas rodadas?** Doze e quatorze, respectivamente, com treze e quinze round keys.
21. **Por que testar estados intermediários?** Para localizar a primeira transformação que diverge da referência.
22. **Cifrar e decifrar o próprio resultado prova conformidade?** Não; dois blocos podem compartilhar o mesmo erro. É preciso comparar com referências independentes.

## Interface e clocks

23. **Qual é a função de MOSI e MISO?** Transportar dados do mestre ao periférico e do periférico ao mestre, respectivamente.
24. **Quem produz SCLK?** O mestre/controlador externo na interface estudada.
25. **O que significa CS_N?** Um sinal de seleção de chip indicado como ativo baixo.
26. **Qual a diferença entre CPOL e CPHA?** CPOL define o nível ocioso do clock; CPHA define em qual das duas bordas ocorre a amostragem.
27. **Por que existem quatro modos SPI?** Porque os dois parâmetros binários CPOL e CPHA têm quatro combinações.
28. **Quais modos amostram na subida?** Modos 0 e 3; os modos 1 e 2 amostram na descida.
29. **O que acontece com modos incompatíveis?** O receptor pode amostrar dados no instante errado e corromper a transferência.
30. **Qual é o cuidado especial com CPHA=0?** Disponibilizar o primeiro bit antes da primeira borda de amostragem.
31. **O SPI define nosso mapa de registradores?** Não. A aplicação deve definir comandos, endereços, ordem de dados e comportamento.
32. **Por que usar registradores entre SPI e AES?** Para reunir operandos recebidos serialmente e expor controle/status; isso é uma hipótese de interface ainda a especificar.
33. **Por que provavelmente existirá CDC?** Porque SCLK externo e clock do sistema podem comandar circuitos com temporizações independentes.
34. **O que é metastabilidade?** Uma condição física em que o flip-flop demora a resolver sua saída, possível após violar setup/hold.
35. **Dois flip-flops eliminam metastabilidade?** Não; aumentam o tempo disponível para resolução e reduzem a probabilidade de falha.
36. **Posso sincronizar cada bit de uma chave separadamente?** Isso não garante uma palavra coerente; é necessário um protocolo apropriado para dados multibit.
37. **Um sincronizador de nível garante capturar um pulso curto?** Não. Pode ser necessário alongar o pulso ou usar um protocolo de transferência.
38. **É obrigatório usar SCLK como clock interno do SPI?** Não. Sobreamostragem é alternativa condicionada à temporização; as entradas continuam assíncronas.

## Ferramentas e decisões de projeto

39. **Por que não implementar o AES inteiro na Semana 1?** O objetivo é dominar fundamentos e validar o ambiente com comportamento fácil de conferir.
40. **Qual a diferença entre lint e simulação?** Lint analisa estruturas do código; simulação executa o modelo com estímulos e observa respostas.
41. **Qual a diferença entre compilação e simulação?** Compilação/elaboração prepara o modelo; simulação o executa.
42. **Qual a diferença entre simulação e síntese?** Simulação avalia comportamento; síntese transforma RTL sintetizável em uma rede lógica.
43. **O que prova o PASS atual?** Que o fluxo instalado executou e que a XOR passou nos quatro casos binários; não prova funcionamento do acelerador.
44. **Por que usar !== no testbench?** Para que X ou Z na saída também causem divergência contra o resultado conhecido.
45. **Por que esperar #1 antes do check?** Para permitir que a atualização combinacional seja processada pelo simulador.
46. **Esse #1 indica atraso físico da XOR?** Não; é uma escolha do testbench em unidades de tempo simuladas.
47. **O que acontece se uma etapa do make falhar?** Seu dependente não executa e o make retorna código diferente de zero.
48. **make -j pode simular antes de compilar?** Não nesta cadeia explícita; no Makefile original as etapas eram independentes.
49. **Por que fixar versões e hashes das ferramentas?** Para identificar e repetir o ambiente utilizado, sem depender de um pacote latest variável.
50. **As ferramentas abertas são necessariamente as definitivas?** Não; as ferramentas do curso ainda precisam ser informadas e validadas.
51. **Uma arquitetura iterativa exige exatamente dez ciclos no AES-128?** Não. Depende da largura do datapath, ciclos por transformação, carga, expansão e controle.
52. **Desenrolar AES sempre aumenta a frequência?** Não. Sem pipeline, o caminho entre entrada e saída pode ficar muito longo.
53. **Menor área sempre significa menor energia?** Não. Atividade, ciclos, tensão, frequência e tempo ativo também importam.
54. **Qual é o custo de guardar as onze round keys do AES-128?** 1408 bits de material de chave, sem contar outros estados.
55. **Uma S-box em case vira sempre ROM?** Não; a síntese decide o mapeamento conforme código, ferramenta e tecnologia.
56. **Já foi escolhido reset ativo baixo?** Não. CS_N ativo baixo não determina a polaridade do reset.
57. **O banco de registradores resolve CDC sozinho?** Não; é armazenamento, e a passagem entre clocks precisa de um protocolo seguro.
58. **Onde estão os requisitos ainda em aberto?** Em docs/spec/pendencias.md, com alternativas, trade-offs e evidências necessárias.
59. **O smoke demonstra baixo consumo?** Não; não houve síntese, análise de atividade ou medição de potência.
60. **O que seria uma boa demonstração ao professor?** Executar clean e smoke, explicar cada comando, a tabela-verdade, as limitações e uma decisão ainda pendente.

## Referências para sustentar as respostas

- [FIPS 197-upd1](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf): seções 3–5, Algoritmos 1–2, Apêndices A–C.
- [NIST: exemplos com valores intermediários](https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines/example-values).
- [Analog Devices: Introduction to SPI Interface](https://www.analog.com/en/resources/analog-dialogue/articles/introduction-to-spi-interface.html): sinais e modos.
- [Intel: Metastability Analysis](https://www.intel.com/content/www/us/en/docs/programmable/683068/18-1/metastability-analysis.html): sincronizadores e MTBF.
- [Verilator: opções de execução](https://verilator.org/guide/latest/exe_verilator.html) e [Icarus: opções de compilação](https://steveicarus.github.io/iverilog/usage/command_line_flags.html).
- As comparações de microarquitetura e as propostas de interface são análise de engenharia, não prescrições dessas referências.
