# Requer GNU Make e um shell POSIX (Linux ou ambiente OSS CAD Suite).
SHELL := sh
.DEFAULT_GOAL := smoke

VERILATOR ?= verilator
IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys
RTL := rtl/smoke_top.sv
TB := tb/tb_smoke_top.sv
AES_RTL := rtl/minisoc_aes/aes_transforms_pkg.sv rtl/minisoc_aes/minisoc_aes_dp.sv
AES_TB := tb/minisoc_aes_dp_tb.sv

.PHONY: smoke lint compile sim check-tools versions clean lint-aes-dp compile-aes-dp sim-aes-dp test-aes-dp synth-aes-dp

# Cadeia explicita: tambem preserva a ordem com make -j.
smoke: sim
	@echo "Semana 1: fluxo minimo concluido com sucesso."

sim: compile
	$(VVP) build/smoke.vvp

compile: lint
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s tb_smoke_top -o build/smoke.vvp $(RTL) $(TB)

lint: check-tools
	$(VERILATOR) --lint-only -Wall --top-module smoke_top $(RTL)

check-tools:
	@for tool in "$(VERILATOR)" "$(IVERILOG)" "$(VVP)"; do \
		command -v "$$tool" >/dev/null 2>&1 || { \
			echo "ERRO: dependencia ausente: $$tool. Consulte README.md." >&2; exit 1; }; \
	done

versions: check-tools
	$(MAKE) --version
	$(VERILATOR) --version
	$(IVERILOG) -V
	$(VVP) -V

# Package deve preceder os consumidores em ambos os compiladores.
test-aes-dp: sim-aes-dp

sim-aes-dp: compile-aes-dp
	$(VVP) build/aes_dp.vvp

compile-aes-dp: lint-aes-dp
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s minisoc_aes_dp_tb -o build/aes_dp.vvp $(AES_RTL) $(AES_TB)

lint-aes-dp: check-tools
	$(VERILATOR) --lint-only -Wall --top-module minisoc_aes_dp $(AES_RTL)

# Opcional: Yosys com plugin slang; nao e dependencia de smoke/test-aes-dp.
synth-aes-dp:
	@command -v "$(YOSYS)" >/dev/null 2>&1 || { echo "ERRO: dependencia ausente: $(YOSYS)." >&2; exit 1; }
	mkdir -p build
	$(YOSYS) -m slang -Q -T -l build/aes_dp_synth.log -s scripts/synth_aes_dp.ys

# Remove somente artefatos conhecidos; nunca faz exclusao recursiva.
# Nao execute clean e smoke como alvos concorrentes; use comandos separados.
clean:
	rm -f build/smoke.vvp build/aes_dp.vvp
