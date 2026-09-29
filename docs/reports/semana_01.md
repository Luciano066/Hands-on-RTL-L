# Relatório de estudo e validação — Semana 1

Data da revisão: 29/09/2026. Projeto acadêmico: acelerador AES com interface SPI e baixo consumo.

## 1. Objetivo e limites

Esta entrega prepara o ambiente, organiza o projeto e estuda as bases necessárias à implementação futura. O único RTL é uma XOR combinacional para verificar o toolchain. Não foram implementados AES, SPI, banco de registradores, CDC ou técnicas de baixo consumo.

O [FIPS 197-upd1, de 2023](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf) é a referência normativa do algoritmo. Ele define operações e resultados, mas não obriga uma arquitetura de hardware específica. O artigo [Introduction to SPI Interface, de Piyu Dhaker](https://www.analog.com/en/resources/analog-dialogue/articles/introduction-to-spi-interface.html) é a referência introdutória da interface. As escolhas ainda dependentes do instrutor estão em [decisões pendentes](../spec/pendencias.md).

## 2. AES

### 2.1 Cifra e variantes

AES, Advanced Encryption Standard, é uma cifra simétrica de bloco: uma chave secreta determina uma transformação reversível de um bloco de entrada em um bloco de saída. Cifrar e decifrar dependem da mesma chave secreta, embora utilizem operações organizadas de maneira diferente. O sufixo da variante indica o tamanho da chave, e não o tamanho do bloco.

| Variante | Chave | Nk: palavras de chave de 32 bits | Bloco | Nr: rodadas | Round keys de 128 bits |
|---|---:|---:|---:|---:|---:|
| AES-128 | 128 bits | 4 | 128 bits | 10 | 11 |
| AES-192 | 192 bits | 6 | 128 bits | 12 | 13 |
| AES-256 | 256 bits | 8 | 128 bits | 14 | 15 |

O bloco tem sempre 128 bits, ou 16 bytes. AES-256 não processa um bloco de 256 bits. As variantes também diferem nas regras da expansão de chave; não basta trocar apenas o contador de rodadas. AES-128 é uma referência didática inicial por permitir estudar a sequência com menos rodadas; o suporte definitivo do IP está pendente. Base: FIPS 197, seções 1, 3.1 e 5, Tabela 3.

O AES de bloco, isoladamente, não especifica como tratar mensagens de tamanho arbitrário, autenticação, padding ou nonces. Modos como CBC, CTR e GCM constituem outra camada; nenhum foi escolhido nesta semana.

### 2.2 State e organização dos bytes

O State é a representação lógica dos 16 bytes em quatro linhas e quatro colunas. Cada coluna contém quatro bytes, equivalentes a uma palavra de 32 bits. A entrada ocupa o State por colunas:

```text
s[r,c] = in[r + 4*c], com r e c entre 0 e 3

       coluna 0   coluna 1   coluna 2   coluna 3
linha 0   in[0]      in[4]      in[8]      in[12]
linha 1   in[1]      in[5]      in[9]      in[13]
linha 2   in[2]      in[6]      in[10]     in[14]
linha 3   in[3]      in[7]      in[11]     in[15]
```

Exemplo didático: a sequência hexadecimal `00 11 22 33 44 55 66 77 88 99 aa bb cc dd ee ff` produz a primeira coluna `00 11 22 33` e a primeira linha `00 44 88 cc`. Na saída aplica-se a relação inversa: `out[r+4*c] = s[r,c]`. A figura 1 e a seção 3.4 do FIPS permitem conferir essa associação.

A matriz não obriga usar uma matriz física de registradores. Em RTL, ela pode ser um vetor de 128 bits ou um arranjo de bytes. É preciso definir explicitamente a correspondência entre índices e fatias do vetor. A ordem de bits transmitidos pelo SPI e a ordem dos bytes do banco de registradores são decisões separadas; nenhuma deve ser inferida automaticamente da notação do FIPS.

### 2.3 Transformações

**SubBytes.** Cada byte é substituído pela saída de uma S-box fixa e bijetiva. É a transformação não linear do caminho de dados. Sua definição combina inversão multiplicativa em GF(2^8), com tratamento especial do zero, e uma transformação afim. A tabela é uma forma de implementar a função, não a única: ROM, lógica combinacional e aritmética em campos compostos são alternativas a avaliar. Referência: seção 5.1.1.

**ShiftRows.** Na cifragem, a linha r sofre rotação de r posições para a esquerda: 0, 1, 2 e 3 posições. Os bytes não mudam de valor; mudam de coluna. Em uma implementação paralela, essa permutação pode corresponder principalmente a conexões. Em uma implementação serializada, pode exigir seleção e controle. Referência: seção 5.1.2.

**MixColumns.** Cada coluna é multiplicada por uma matriz fixa sobre GF(2^8). É uma transformação linear e invertível que mistura os quatro bytes da coluna. Com ShiftRows, distribui a influência de bytes entre colunas ao longo das rodadas. Para uma coluna `[a0,a1,a2,a3]`, o primeiro byte resultante é:

```text
b0 = (02 · a0) XOR (03 · a1) XOR a2 XOR a3
```

Os coeficientes são hexadecimais e o produto é no campo finito, não uma multiplicação inteira comum. GF(2^8) tem 256 elementos. Bytes representam polinômios com coeficientes binários; a soma é XOR e o produto é reduzido módulo `x^8 + x^4 + x^3 + x + 1` (0x11B). Multiplicar por 02 pode ser realizado por deslocamento e redução; multiplicar por 03 equivale ao resultado por 02 XOR o byte original. Referências: seções 4 e 5.1.3.

**AddRoundKey.** Combina os 128 bits do State com os 128 bits da chave da rodada por XOR. Para uma chave fixa, a operação é sua própria inversa: `(x XOR k) XOR k = x`. Tem implementação simples em portas lógicas, mas XOR sozinho não constitui o AES. É a transformação de rodada que recebe diretamente material da chave. Referência: seção 5.1.4.

### 2.4 Estrutura e última rodada

A cifragem segue esta sequência, definida no Algoritmo 1 do FIPS:

1. Carregar o State e aplicar AddRoundKey com a chave de rodada 0.
2. Executar Nr−1 rodadas com SubBytes, ShiftRows, MixColumns e AddRoundKey, nessa ordem.
3. Executar a rodada Nr com SubBytes, ShiftRows e AddRoundKey.
4. Serializar o State como os 16 bytes de saída.

Portanto, AES-128 tem uma adição inicial, nove rodadas completas e uma rodada final. A adição inicial não é contada como uma das dez rodadas.

Por que não há MixColumns na última rodada? Para a implementação, a razão normativa é que o algoritmo padronizado assim o define; incluí-la mudaria os resultados e deixaria de corresponder aos vetores AES. O FIPS descreve essa diferença, mas não apresenta ali uma prova histórica da motivação de projeto.

Como interpretação algébrica, uma transformação linear invertível na extremidade não acrescenta uma nova camada não linear: se M representa MixColumns, então `M(z XOR k) = M(z) XOR M(k)`. Assim, é possível relacionar uma mistura terminal a uma transformação pública da saída, ajustando a representação da última chave. Isso ajuda a entender a distinção entre difusão nas rodadas internas e uma operação terminal. Não autoriza remover MixColumns das rodadas internas, mudar a chave definida pelo padrão ou afirmar uma prova geral de segurança. O controle RTL futuro terá de distinguir a última rodada.

### 2.5 Key Expansion e round keys

Key Expansion deriva deterministicamente as chaves de rodada a partir da chave original; não cria nova entropia nem chaves secretas independentes. O resultado tem `4*(Nr+1)` palavras de 32 bits: 44, 52 ou 60 palavras, respectivamente, para AES-128, AES-192 e AES-256. Cada grupo de quatro palavras fornece uma round key de 128 bits.

As primeiras Nk palavras são copiadas da chave de entrada. As demais combinam palavras anteriores por XOR; em posições específicas entram RotWord (rotação de um byte), SubWord (S-box aplicada aos quatro bytes) e Rcon (constante de rodada). AES-256 inclui uma aplicação adicional de SubWord em posições específicas. Referência: seção 5.2, Algoritmo 2 e Apêndice A.

Para AES-128, são onze round keys: a inicial e dez para as rodadas. Armazenar todas exige 11 × 128 = 1408 bits apenas para esse material; registradores de controle e outros dados são adicionais. Gerá-las durante a operação pode reduzir armazenamento, mas exige coordenar a disponibilidade da chave com o processamento e, eventualmente, a decifragem. A estratégia permanece pendente.

### 2.6 Vetores oficiais e estados intermediários

Resultados oficiais permitem comparar uma implementação com uma referência independente. Um teste de cifrar e depois decifrar, usando dois blocos com o mesmo erro de ordenação, pode passar sem que ambos sejam AES correto.

O Apêndice A fornece exemplos de expansão; o Apêndice B acompanha a cifragem; o Apêndice C da edição atual aponta para exemplos adicionais. O NIST publica [exemplos com valores intermediários](https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines/example-values) para as três variantes. Nas próximas semanas, devem ser usados tanto o resultado final quanto estados após transformações e round keys: a primeira divergência ajuda a localizar erro de State, S-box, aritmética ou controle.

Passar em alguns vetores não equivale a certificação NIST, prova formal ou resistência a ataques físicos. Nenhum vetor AES foi executado nesta semana: o smoke verifica uma XOR.

## 3. SPI

### 3.1 Sinais e temporização

SPI é comunicação serial síncrona: um mestre/controlador fornece SCLK e seleciona o periférico por CS. No arranjo de quatro fios estudado, MOSI leva dados do mestre ao periférico e MISO faz o caminho inverso, permitindo transferência simultânea. CS_N explicita seleção ativa baixa; o comportamento exato do dispositivo depende da especificação.

CPOL determina o nível ocioso de SCLK. CPHA escolhe a primeira ou a segunda borda de cada período para amostragem. A primeira borda sai do nível ocioso; a segunda retorna a ele.

| Modo | CPOL | CPHA | Ocioso | Borda de amostragem | Borda de atualização/deslocamento |
|---|---:|---:|---|---|---|
| 0 | 0 | 0 | Baixo | Primeira: subida | Segunda: descida |
| 1 | 0 | 1 | Baixo | Segunda: descida | Primeira: subida |
| 2 | 1 | 0 | Alto | Primeira: descida | Segunda: subida |
| 3 | 1 | 1 | Alto | Segunda: subida | Primeira: descida |

Com CPHA=0, o primeiro bit já deve estar válido antes da primeira borda. Com CPHA=1, é lançado na primeira e amostrado na segunda. Além do modo compatível, é necessário cumprir setup/hold e temporização de CS. Referência: [Analog Devices, seções de sinais e modos SPI](https://www.analog.com/en/resources/analog-dialogue/articles/introduction-to-spi-interface.html).

### 3.2 Aplicação ao acelerador

Como hipótese de integração, uma transação pode carregar chave e bloco, outra solicitar processamento, e leituras podem recuperar status e resultado. Isso permite controlar o acelerador usando poucos pinos. Essa sequência é uma proposta didática de uso; endereços, comandos, tamanho de palavra, ordem de bits, pausas e tratamento de erros ainda não são requisitos definidos.

Um banco de registradores pode guardar bytes recebidos em instantes diferentes, expor controle/status e manter operandos estáveis durante o cálculo. FIFO ou comandos com buffers são alternativas. A seleção entre elas depende da taxa de transferência e do protocolo. O banco de registradores não substitui a análise de CDC.

## 4. Domínios de clock e CDC

Se o receptor SPI usar SCLK como clock e o núcleo AES usar o clock interno do sistema, haverá dois domínios. O controlador externo pode variar ou interromper SCLK; sem relação temporal garantida, um sinal pode mudar próximo à borda do clock que o recebe.

Essa situação pode violar setup/hold de um flip-flop e produzir metastabilidade: a saída pode demorar mais do que o previsto para atingir um nível lógico válido. Não é um terceiro valor lógico estável que a simulação RTL comum represente fielmente.

Sincronizadores dão tempo para a resolução e reduzem a probabilidade de propagação da falha, sem oferecer garantia absoluta em tempo finito. A [introdução da Intel à análise de metastabilidade](https://www.intel.com/content/www/us/en/docs/programmable/683068/18-1/metastability-analysis.html) descreve cadeias de registradores e MTBF como medida de confiabilidade.

A análise de engenharia deve diferenciar tipos de transferência: um nível de controle isolado, um pulso curto e um bloco de 128 bits têm necessidades diferentes. Dois flip-flops em cada bit não garantem que um barramento seja capturado de forma coerente. Um pulso também pode desaparecer antes de o destino amostrá-lo.

Handshake com dados estáveis e FIFO assíncrona são alternativas para discutir; a escolha depende de frequência, vazão, largura e possibilidade de SCLK parar. Outra hipótese é amostrar sinais SPI no domínio do sistema, desde que exista uma relação temporal suficientemente restrita e verificada. Mesmo nessa hipótese há entradas assíncronas a tratar. A estratégia definitiva não foi escolhida.

## 5. Ambiente e smoke test

A inspeção inicial encontrou sete arquivos numa pasta duplicada, sem metadados Git. Já existiam RTL XOR, testbench, Makefile, script Bash, README, backlog e relatório introdutório. Faltavam os diretórios anunciados, preparação para Windows, evidência de execução e detalhamento técnico da defesa. Os arquivos foram movidos para a raiz, preservando e ampliando suas funções.

O smoke é preferível nesta etapa porque sua tabela-verdade cabe em quatro casos. Se o fluxo falhar, é possível investigar ferramenta, sintaxe, caminhos e testbench sem confundir o problema com uma implementação criptográfica ainda não estudada.

O RTL usa `assign y = a ^ b`, sem clock, estado ou reset. O testbench aplica 00, 01, 10 e 11 e compara resultados explícitos com `!==`, detectando também X/Z inesperados. O atraso de 1 ns permite a atualização do circuito no simulador; não representa atraso físico medido. O sucesso encerra a simulação com `$finish`; a divergência usa `$fatal(1,...)`. Há um limite de 100 ns de tempo simulado; ele não é um watchdog de tempo de parede para travamento de ferramentas.

O Makefile implementa a cadeia `smoke → sim → compile → lint → check-tools`. Os pré-requisitos executam antes de seus dependentes, garantindo lint, compilação e simulação nessa ordem, inclusive com `make -j`. Os alvos são phony para repetir o teste sem confiar em artefatos antigos. O custo de recompilar a XOR é desprezível.

| Etapa | Função nesta entrega | Limite |
|---|---|---|
| Lint | Verilator verifica estaticamente o RTL com `--lint-only -Wall` | Não demonstra a função para todos os projetos nem CDC seguro |
| Compilação/elaboração | Icarus analisa RTL + TB, resolve hierarquia e gera `smoke.vvp` | Aceitar sintaxe não demonstra comportamento correto |
| Simulação | vvp executa os quatro casos autochecking | Só verifica o modelo e os estímulos executados |
| Síntese | Etapa futura: converter RTL em lógica e mapear para tecnologia | Não foi executada; área/timing/potência desconhecidos |

A detecção de dependências não pula etapas ausentes. Erros das ferramentas interrompem o Makefile. O alvo clean remove somente o executável gerado conhecido. As instruções de instalação e ativação constam no [README](../../README.md).

## 6. Evidências e aceite

Comandos, versões, resultados, warnings, ensaios de falha e verificação a partir de diretório limpo estão registrados em [semana_01_validacao.md](semana_01_validacao.md). Esse documento distingue o que foi observado do que ainda precisa de ferramentas ou requisitos futuros.

O smoke não usa PDK e não exige síntese para cumprir seu objetivo. As ferramentas oficiais do curso e a tecnologia serão registradas quando informadas. O backlog mantém essas pendências sem apresentá-las como falhas do teste mínimo.

## 7. Continuidade

A próxima etapa deve resolver as [pendências funcionais](../spec/pendencias.md), comparar opções de arquitetura e só então implementar transformações AES com referências independentes. A discussão de baixo consumo deve considerar atividade, capacitância, tensão e frequência, além de latência e energia por operação. Nenhuma economia de potência foi medida ou prometida nesta entrega.

Para preparar a apresentação, consultar [decisões e perguntas da arguição](semana_01_defesa.md).
