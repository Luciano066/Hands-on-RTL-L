# Requer GNU Make e um shell POSIX (Linux ou ambiente OSS CAD Suite).
SHELL := sh
.DEFAULT_GOAL := smoke

VERILATOR ?= verilator
IVERILOG ?= iverilog
VVP ?= vvp
RTL := rtl/smoke_top.sv
TB := tb/tb_smoke_top.sv

.PHONY: smoke lint compile sim check-tools versions clean

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

# Remove somente o artefato conhecido; nunca faz exclusao recursiva.
# Nao execute clean e smoke como alvos concorrentes; use comandos separados.
clean:
	rm -f build/smoke.vvp
