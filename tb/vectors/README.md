# Vetores do datapath AES-128

O testbench `../minisoc_aes_dp_tb.sv` contém constantes de referência públicas;
nenhum vetor é extraído do Block Guide confidencial.

- [NIST AES_Core128.pdf](https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Standards-and-Guidelines/documents/examples/AES_Core128.pdf): quatro pares plaintext/ciphertext da seção ECB-AES128, páginas 1–6; primeiro bloco com estados intermediários de encrypt nas páginas 1–2 e de decrypt nas páginas 7–8 (numeração física do PDF).
- [FIPS 197-upd1](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf): apêndice A.1 para K0..K10 da chave `2b7e151628aed2a6abf7158809cf4f3c`; tabela 4 para a S-box no RTL; equações 5.2/5.3 para o oráculo algébrico do TB; seções 5.1 e 5.3 para transformações e matrizes inversas.

`enc_trace` guarda a adição inicial e cada saída após AddRoundKey.
`dec_trace` guarda a adição inicial com K10, saídas após InvMixColumns
nas nove rodadas internas e a saída final com K0. A apresentação NIST
permuta InvSubBytes/InvShiftRows, que comutam; o DUT usa a ordem INVCIPHER
do FIPS e chaves sem transformação, não EQINVCIPHER.

Os quatro blocos são processados **separadamente pelo testbench**; isso não
valida um controlador ECB, RAM ou processamento multi-bloco implementado.
O TB fornece as onze chaves: não há Key Expansion RTL ou modelo gerador no TB.

Além das constantes NIST, a verificação inclui todas as 256 entradas da S-box
forward/inverse em todas as posições, matrizes GF(2^8) independentes nos 128
vetores de base e em 256 estados determinísticos, permutações explícitas com
bytes distintos, inversibilidade e prioridade dos seletores de rodada.
O oráculo de substituição usa inversão algébrica e o de mistura usa produto
polinomial com redução por `0x11b`, sem consultar funções/tabelas do DUT.

Byte `i` ocupa `[127-8*i -: 8]`; `s[row,col]=byte[row+4*col]`.
As quatro palavras de memória correspondem, em ordem, a `[127:96]`,
`[95:64]`, `[63:32]`, `[31:0]`.
