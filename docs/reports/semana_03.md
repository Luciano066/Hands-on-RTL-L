# Semana 3 — Datapath AES-128 forward/inverse

Data da execução: 29/10/2026. Revisão de referência: `be42888`.
**RTL do marco implementado e testado; aceite do instrutor pendente.**
A Semana 2 permanece sem apresentação/aprovação registradas.

## Implementação e interface

O [datapath](../../rtl/minisoc_aes/minisoc_aes_dp.sv) compõe uma rodada
combinacional reutilizável. O [package](../../rtl/minisoc_aes/aes_transforms_pkg.sv)
implementa SubBytes, ShiftRows, MixColumns, AddRoundKey e três inversas,
sem delays, clocks ou inicialização dependente de simulação. S-boxes são
cases completos; misturas usam xtime/XOR com limites constantes.

Portas e ordem INVCIPHER estão na [arquitetura v1.1, seção 8](../architecture/arquitetura_v1.1.md).
Inicial faz XOR; final omite mistura. Initial prevalece sobre final.
As chaves fornecidas são normais, K0..K10 forward e K10..K0 inverse,
sem transformação de round keys para EQINVCIPHER. Registros de State,
FSM, Key Expansion e sequenciamento multi-bloco ficam para a Semana 4/futuro.

Byte i ocupa `[127-8*i -: 8]`, State por colunas; as quatro palavras
correspondem a `[127:96]`, `[95:64]`, `[63:32]`, `[31:0]`.
Essa ordem é verificada por permutações explícitas e vetores oficiais.

## Testes autochecking e origem

O [testbench](../../tb/minisoc_aes_dp_tb.sv) fornece chaves constantes do
FIPS 197 A.1 e pares/estados intermediários públicos do NIST AES_Core128.
Links, páginas e fronteiras do State estão em [origem dos vetores](../../tb/vectors/README.md).
Nenhum vetor foi copiado do material confidencial.

| Grupo | Verificações |
|---|---:|
| S-box/inversa, 256 entradas em todas as posições, oráculo algébrico | 512 |
| Sete transformações com valores NIST e duas permutações explícitas de bytes | 9 |
| MixColumns/inversa nos 128 vetores de base, matriz independente | 256 |
| 256 estados determinísticos: inversibilidade e matriz independente | 1536 |
| Estados intermediários do primeiro bloco forward/inverse | 22 |
| Quatro KATs de cifragem e quatro de decifragem | 8 |
| Prioridade de initial/final em ambos os sentidos | 2 |
| **Total** | **2345** |

O oráculo S-box calcula inversão no campo e transformação afim, sem consultar
a tabela do DUT. O oráculo MixColumns usa multiplicação polinomial/redução
por 0x11b e matriz independente da implementação otimizada. Inversibilidade
é evidência complementar, não o único oráculo. Comparações usam `!==` e `$fatal`.
Timeout limita simulações com regressão.

Os quatro blocos dos exemplos são aplicados separadamente pelo TB,
reusando a rodada dez vezes com chaves externas. Isso comprova composição
da primitiva, sem alegar engine sequencial, RAM, modo ECB ou controlador
multi-bloco já implementados no RTL.

## Ferramentas reais

Instalação portátil existente em `.tools/`, ativada somente no processo.

| Ferramenta | Versão observada |
|---|---|
| GNU Make | 4.4.1, x86_64-pc-cygwin |
| Verilator | 5.053 devel, v5.052-119-g014c9820d (mod); executável `verilator_bin` |
| Icarus Verilog / vvp | 14.0 devel, s20260301-500-g2e81fcccb-dirty |
| Yosys | 0.69+154, git 30d62572e-dirty, frontend slang instalado |

Nenhuma atualização do toolchain RTL foi necessária. Bibliotecas de leitura
do PDF foram instaladas apenas em build, fora das dependências deste teste.

## Comandos e resultados observados

Na raiz do projeto, Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_aes_dp.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_smoke.ps1
```

Com uma sessão ativada conforme README, equivalentes Make:

```text
make versions
make clean
make -j4 smoke test-aes-dp
make synth-aes-dp
```

Limpeza e construção foram executadas em sequência, não como alvos concorrentes.
O alvo AES executa `verilator_bin --lint-only -Wall`, Icarus com
`-g2012 -Wall -s minisoc_aes_dp_tb` e depois `vvp build/aes_dp.vvp`.
O package precede o módulo na ordem de compilação. `make smoke` mantém
lint/compilação/simulação do XOR sem depender de AES ou Yosys.

| Execução | Resultado e limite |
|---|---|
| Smoke antes das alterações | PASS, quatro casos XOR, exit 0, sem warnings |
| Primeira simulação AES | PASS, 2345 checks; Icarus avisou sobre sensibilidade conservadora em always_comb |
| Fluxo AES após ajuste para always @* | PASS, exit 0, Verilator/Icarus sem warnings |
| Reconstrução limpa conjunta `make -j4 smoke test-aes-dp` | PASS dos dois alvos, exit 0, sem warnings |
| Síntese genérica Yosys/slang com `synth -noabc` e `check -assert` | PASS, exit 0, zero problemas no check |

Saídas funcionais observadas:

```text
SMOKE TEST PASS
AES DATAPATH TEST PASS: 2345 checks, 4 encrypt + 4 decrypt KATs
```

A simulação AES terminou em 90 ns de tempo artificial do TB. Esse valor mede
apenas passos de estímulo com `#1`; **não é latência física do hardware**.
O ajuste de sensibilidade não suprimiu opções de lint ou diagnósticos; removeu
uma limitação do Icarus preservando um bloco completamente combinacional.

O script opcional [synth_aes_dp.ys](../../scripts/synth_aes_dp.ys) gera lógica
genérica sem biblioteca/ABC ou restrições de timing. O check encontrou zero
problemas e a estatística final contém somente mux/not/xor, sem FF/latch.
Isso é evidência de sintetizabilidade neste frontend, não área física ou
atendimento a 250 MHz–2 GHz. Yosys/slang é opcional para os testes normais.
Logs locais ficam em `build/final_regression.log` e `build/aes_dp_synth.log`,
ignorados pelo Git. Os comandos permitem regenerar a evidência.

## Revisão final, limites e próximos passos

V1.0 e os onze arquivos históricos monitorados permanecem preservados.
Links relativos, whitespace e ausência de documentos confidenciais no diff
são conferidos na autoauditoria da retomada. O Mermaid é fonte para
renderizadores compatíveis; não foi validado no renderizador oficial nesta execução.

Não houve simulação executável via Verilator: ele foi usado para lint; a
simulação foi executada no Icarus/vvp. Bash/Make usam shell POSIX do Git no
Windows; não foi executado sistema Linux nativo. Nenhum teste de SPI, CDC,
RAM, PLL, modos, top-level, formal, STA, potência ou MTBF foi realizado.

Na Semana 4, implementar expansão e comparar as onze chaves, adicionar
controle/registros com testes de captura/reset/última rodada e validar as
primitivas sequenciais. Antes de integrar modos/memória, resolver feedback
CFB, overflow CTR, latência da RAM, ownership e reset/PLL com instrutor/DV.
