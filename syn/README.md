# Síntese futura

Atualização de 29/10/2026: foi executada síntese **genérica** do datapath AES
com Yosys/slang (`make synth-aes-dp`), com zero problemas no check e sem
FF/latches na estatística final. O [script](../scripts/synth_aes_dp.ys) não
usa biblioteca/PDK, ABC ou constraints físicos. Veja [Semana 3](../docs/reports/semana_03.md).
Área, timing e potência continuam sem medição. O parágrafo abaixo preserva
o estado histórico da Semana 1.

Diretório reservado para scripts de síntese, bibliotecas e restrições SDC após definição da tecnologia e dos clocks. A XOR atual é descrita em um subconjunto sintetizável, mas esta entrega não executa síntese nem mede área, timing ou potência. Compilar para simulação não produz uma netlist mapeada para o PDK.
