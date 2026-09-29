# Inventário de alterações — Semana 1

## Inspeção anterior às alterações

Foram lidos os sete arquivos existentes em `semana_01_aes_spi/`, dentro da raiz já chamada `semana_01_aes_spi`: README, BACKLOG, Makefile, RTL XOR, testbench, script Bash e relatório. Não havia metadados Git no projeto.

A base continha conteúdo útil: escopo inicial, cronograma preliminar, descrição introdutória AES/SPI e teste XOR com quatro entradas. As fragilidades eram a raiz duplicada, diretórios somente anunciados, dependências ausentes, etapas Make sem encadeamento, script dependente do diretório de chamada e ausência de evidência executada e roteiro de defesa. O relatório não detalhava suficientemente organização do State, Key Expansion e CDC.

Os sete arquivos foram movidos para a raiz correta e revisados. A XOR e a tabela-verdade foram preservadas. Afirmações que sugeriam arquitetura definitiva foram reformuladas como hipóteses. Os diretórios vazios da estrutura antiga foram removidos depois de conferir que não continham mais arquivos; nenhum conteúdo útil foi apagado. O ZIP original situado acima da raiz não foi alterado.

## Todos os arquivos da entrega

Caminhos relativos à raiz atual. “Movido e revisado” significa que havia um arquivo correspondente na subpasta duplicada original.

| Arquivo | Situação | Modificação e finalidade |
|---|---|---|
| README.md | Movido e revisado | Escopo, estrutura real, dependências, bootstrap Windows, ativação, comandos, limitações e links |
| BACKLOG.md | Movido e revisado | Aceite baseado na execução; pendências do curso separadas; planejamento futuro preservado e baixo consumo acrescentado |
| Makefile | Movido e revisado | Dependências em cadeia, verificação de ferramentas, tops explícitos, flags, versões e limpeza restrita |
| rtl/smoke_top.sv | Movido e revisado | XOR preservada; timescale e default_nettype explícitos, comentários de escopo |
| tb/tb_smoke_top.sv | Movido e revisado | Quatro casos preservados com literais de 1 bit, fatal explícito e limite de tempo simulado |
| scripts/run_smoke.sh | Movido e revisado | Localização da raiz pelo próprio script e propagação do status com exec |
| docs/reports/semana_01.md | Movido e revisado | Estudo ampliado de AES, SPI, CDC, toolchain e limites da entrega |
| .gitignore | Criado | Exclui ferramentas portáteis, build, obj_dir e ondas do versionamento |
| .gitattributes | Criado | Convenções de texto/LF para fontes, Makefile, scripts e documentos |
| scripts/bootstrap_windows.ps1 | Criado | Download e verificação de pacotes fixados, extração local e execução clean/smoke |
| scripts/activate_tools.ps1 | Criado | PATH da sessão, shell do Git e seleção/configuração do Verilator nativo |
| scripts/run_smoke.ps1 | Criado | Entrada Windows, opção Clean, localização da raiz e retorno de falhas |
| docs/spec/pendencias.md | Criado | Escopo confirmado e 13 decisões abertas com alternativas e critérios |
| docs/architecture/README.md | Criado | Arquitetura reservada, hipótese de integração e restrições de escopo |
| docs/reports/semana_01_defesa.md | Criado | 20 decisões com cinco campos e 60 perguntas/respostas progressivas |
| docs/reports/semana_01_validacao.md | Criado | Versões, hashes, comandos, resultados, correções, ensaios negativos e aceite |
| docs/reports/semana_01_alteracoes.md | Criado | Este inventário e diagnóstico inicial |
| formal/README.md | Criado | Finalidade futura e indicação de que não houve prova formal |
| syn/README.md | Criado | Finalidade futura e distinção entre síntese e compilação de simulação |
| upf/README.md | Criado | Intenção de potência futura, sem antecipar UPF ou técnicas |

## Metadados e artefatos locais

Foi criado `.git/` por `git init`, sem commit, remoto ou alteração de identidade/configuração global. Como a pasta inicial não era um repositório Git, os 20 arquivos da entrega aparecem como untracked; isso é esperado antes do primeiro commit.

`.tools/` contém os dois pacotes baixados, suas distribuições extraídas e respectivas licenças. Não deve ser enviado como parte dos fontes.

`build/smoke.vvp` é o executável da simulação. Em `build/verification/` foram criados apenas para diagnóstico: `or/smoke_top.sv`, `width/smoke_top.sv`, `syntax/smoke_top.sv`, `validate.ps1` e uma cópia limpa `clean-source/` de Makefile, rtl e tb, com seu executável gerado. Esses arquivos de ensaio contêm erros intencionais e estão fora das listas de fontes normais. Artefatos auxiliares de conferência também permanecem sob build, ignorados pelo Git. Os ensaios e resultados estão no relatório de validação.

`make clean` remove apenas o executável conhecido `build/smoke.vvp`, que pode ser recriado. Não remove ferramentas, logs, testes de diagnóstico ou arquivos de estudo.
