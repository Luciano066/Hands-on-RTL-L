# Validação executada — Semana 1

Data: 29/09/2026. Ambiente: Windows x64, PowerShell 5.1 e Git for Windows 2.54.0.windows.1. Execução local; sem síntese, PDK ou serviço remoto de simulação.

## 1. Situação encontrada e correções

A inspeção inicial mostrou ausência de `make`, `verilator`, `iverilog` e `vvp` no PATH. O executável WSL existia, mas `wsl --list --verbose` confirmou que não havia distribuição instalada. Existia Git for Windows com shell POSIX.

As dependências foram preparadas em `.tools/`, sem instalação global. O primeiro bootstrap encontrou ausência de Make no pacote Windows; GNU Make do MSYS2 foi acrescentado ao bootstrap. O lançador Perl do Verilator falhou por ausência de `Pod/Usage.pm`; para o lint, a ativação passou a usar o executável nativo `verilator_bin`. Também foi necessário definir `VERILATOR_ROOT` para o diretório `share/verilator` da distribuição, pois o binário inicialmente procurava seus includes em `/yosyshq`.

O sandbox da sessão bloqueou rede, enumeração inicial do WSL e algumas criações de processo MSYS. As operações necessárias foram executadas com a autorização de execução solicitada pela ferramenta. Uma tentativa de dot-source também foi bloqueada pela política padrão de scripts do PowerShell; os comandos documentados usam `-ExecutionPolicy Bypass` somente no processo iniciado. Nenhuma política global foi alterada.

Essas falhas de preparação foram corrigidas antes do aceite. O comando completo de bootstrap, com as versões finais dos scripts, retornou zero e executou clean/smoke com sucesso reutilizando os pacotes já baixados.

## 2. Identificação do toolchain

| Componente | Identificação observada |
|---|---|
| OSS CAD Suite | windows-x64, release 2026-09-28 |
| GNU Make | 4.4.1, build x86_64-pc-cygwin; pacote MSYS2 4.4.1-3 |
| Verilator | 5.053 devel rev v5.052-119-g014c9820d (mod) |
| Icarus Verilog | 14.0 (devel), s20260301-500-g2e81fcccb-dirty |
| vvp | 14.0 (devel), s20260301-500-g2e81fcccb-dirty |
| Git | 2.54.0.windows.1 |

As palavras `devel`, `mod` e `dirty` fazem parte dos identificadores fornecidos pelos binários distribuídos; não significam alteração do RTL desta entrega. Não são versões estáveis certificadas pelo curso. Versão e hash foram registrados para identificar o ambiente efetivamente testado.

Pacotes conferidos por SHA256 antes da extração:

| Pacote | SHA256 |
|---|---|
| oss-cad-suite-windows-x64-20260928.tgz | `71a0a16592db2070e6abf18f76463dcc6bc0c7d6c772f29a7fd925197a29e184` |
| make-4.4.1-3-x86_64.pkg.tar.zst | `af0bdba17f06fe037f0194069adaa31a8fe45f1a11381501896aea1fae37bd5d` |

Origem: [release OSS CAD Suite 2026-09-28](https://github.com/YosysHQ/oss-cad-suite-build/releases/tag/2026-09-28) e [pacote GNU Make do MSYS2](https://packages.msys2.org/packages/make). O primeiro digest veio dos metadados da release oficial; o segundo, da página oficial do pacote.

## 3. Comandos realmente executados

Preparação e execução pelo PowerShell, a partir da raiz:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap_windows.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_smoke.ps1 -Clean
```

O segundo comando ativa ferramentas apenas no processo, muda para a raiz e executa, verificando os códigos de saída:

```sh
make clean
make smoke
```

Comandos expandidos pelo Makefile no Windows:

```text
rm -f build/smoke.vvp
verilator_bin --lint-only -Wall --top-module smoke_top rtl/smoke_top.sv
mkdir -p build
iverilog -g2012 -Wall -s tb_smoke_top -o build/smoke.vvp rtl/smoke_top.sv tb/tb_smoke_top.sv
vvp build/smoke.vvp
SMOKE TEST PASS
tb/tb_smoke_top.sv:35: $finish called at 4000 (1ps)
Semana 1: fluxo minimo concluido com sucesso.
```

O trecho acima omite apenas o relatório informativo de tempo/memória do Verilator. `4000 (1ps)` corresponde a 4 ns, após quatro verificações com atraso de 1 ns cada.

| Etapa | Resultado observado | Diagnósticos no smoke final |
|---|---|---|
| make clean | Exit 0 | Nenhum |
| Lint Verilator | Aprovado | Zero warnings; apenas relatório informativo |
| Compilação Icarus | Aprovada, build/smoke.vvp gerado | Zero warnings |
| Simulação vvp | Quatro casos aprovados, término automático | PASS e mensagem informativa de $finish |
| make smoke | Exit 0 | Mensagem final de sucesso |

A consulta `make versions` também retornou zero. O vvp escreve informações de versão/licença em stderr; na captura pelo PowerShell 5.1 surgiram objetos `RemoteException` para linhas desse fluxo. Não foram warnings do RTL nem falha do runtime: o código de saída foi zero. Esse detalhe da captura não ocorreu na execução normal do smoke.

## 4. Validações adicionais

Foram usadas cópias temporárias em `build/verification/`, ignoradas pelo Git. O RTL entregue em `rtl/` permaneceu XOR durante os ensaios.

| Ensaio | Como foi exercitado | Resultado |
|---|---|---|
| Ordem sob paralelismo | `make -j4 smoke` | Exit 0; lint antes de compile, compile antes de sim |
| Dependência ausente | `make smoke VERILATOR=ferramenta_inexistente_semana1` | Exit 2; diagnóstico explícito, sem anúncio de sucesso |
| Warning real de lint | Cópia do RTL com `assign y = {a,b}` | WIDTHTRUNC fatal; make exit 2, sem compilação/simulação |
| Erro real de compilação | Cópia com `assign y = ;`, usando `VERILATOR=true` apenas neste ensaio | Icarus acusou erro de sintaxe; make exit 2, sem simulação |
| Erro funcional real | Cópia trocando XOR por OR | TB falhou em a=1, b=1, y=1, expected=0; make exit 2 |
| Falha do comando de simulação | `make smoke VVP=false` | make exit 2; sem mensagem de sucesso |
| Fontes sem build | Copiar somente Makefile, rtl/ e tb/ para diretório novo | `make clean` e `make smoke`: exit 0 |
| Alvo sim independente | `make sim` na cópia sem build | Executou dependências e passou |
| Scripts fora da raiz | Bash e PowerShell chamados a partir de .tools/ | Ambos localizaram a raiz e retornaram zero |
| Restauração do artefato principal | `make clean` e `make smoke` com RTL original | Exit 0, PASS |

`VERILATOR=true` foi uma injeção deliberada e isolada para alcançar o erro do compilador; não está no Makefile nem na ativação normal. O smoke final sempre executou Verilator real.

A divergência funcional produziu:

```text
FATAL: tb/tb_smoke_top.sv:22: FAIL: a=1 b=1 y=1 expected=0
       Time: 4000  Scope: tb_smoke_top.check
make: *** [Makefile:19: sim] Error 1
```

O Make retorna 2 para falha de receita, embora a ferramenta que falhou possa retornar 1. Ambos são diferentes de zero e indicam erro para automação. Os números de linha dos diagnósticos são os observados no momento de cada ensaio.

A cópia limpa demonstra independência de artefatos de compilação anteriores. Ela reutilizou o toolchain local já ativado; não representa teste numa nova instalação do sistema operacional. A instalação inicial partiu de uma máquina sem as ferramentas RTL no PATH, mas com Git, PowerShell, curl e tar existentes.

## 5. Critério de aceite e limitações

O critério da Semana 1 no fluxo aberto foi atendido: estrutura documentada, backlog, estudos e defesa disponíveis; um comando executa sequencialmente lint, compilação e simulação; sucesso e falhas são observáveis; reconstrução a partir de fontes limpas foi testada.

Continuam pendentes de informação do instrutor: ferramentas oficiais, tecnologia/PDK e decisões funcionais P01–P13. Isso não impede a execução do smoke, que não utiliza biblioteca de células.

Não foram executados: AES, SPI, CDC em hardware, síntese, formal, timing físico ou análise de potência. A receita Linux está documentada, mas não foi validada nesta máquina Windows.
