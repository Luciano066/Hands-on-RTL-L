# Síntese futura

Semana 4, 29/10/2026: `make synth-aes` também verifica Key Expansion e core
sequencial, com scripts `scripts/synth_aes_key.ys` e `scripts/synth_aes_core.ys`.
Os três checks passaram sem problemas. O core contém FFs, sem latches na
estatística final; não houve mapeamento físico ou análise de timing/potência.
Veja [evidências da Semana 4](../docs/reports/semana_04.md).

Atualização de 29/10/2026: foi executada síntese **genérica** do datapath AES
com Yosys/slang (`make synth-aes-dp`), com zero problemas no check e sem
FF/latches na estatística final. O [script](../scripts/synth_aes_dp.ys) não
usa biblioteca/PDK, ABC ou constraints físicos. Veja [Semana 3](../docs/reports/semana_03.md).
Área, timing e potência continuam sem medição. O parágrafo abaixo preserva
o estado histórico da Semana 1.

Diretório reservado para scripts de síntese, bibliotecas e restrições SDC após definição da tecnologia e dos clocks. A XOR atual é descrita em um subconjunto sintetizável, mas esta entrega não executa síntese nem mede área, timing ou potência. Compilar para simulação não produz uma netlist mapeada para o PDK.
