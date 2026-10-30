# Requer GNU Make e um shell POSIX (Linux ou ambiente OSS CAD Suite).
SHELL := sh
.DEFAULT_GOAL := smoke

VERILATOR ?= verilator
IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys
RTL := rtl/smoke_top.sv
TB := tb/tb_smoke_top.sv
AES_PKG := rtl/minisoc_aes/aes_transforms_pkg.sv
AES_TRANSFORMS_RTL := $(AES_PKG) rtl/minisoc_aes/minisoc_aes_sbox.sv rtl/minisoc_aes/minisoc_aes_sub_bytes.sv rtl/minisoc_aes/minisoc_aes_shift_rows.sv
AES_DP_RTL := $(AES_PKG) rtl/minisoc_aes/minisoc_aes_dp.sv
AES_KEY_RTL := $(AES_PKG) rtl/minisoc_aes/minisoc_aes_key_exp.sv
AES_CORE_RTL := $(AES_DP_RTL) rtl/minisoc_aes/minisoc_aes_key_exp.sv rtl/minisoc_aes/minisoc_aes_core.sv

.PHONY: smoke lint compile sim check-tools versions clean test-aes regression synth-aes check-synth-tools

# Cadeia explicita: tambem preserva a ordem com make -j.
smoke: sim
	@echo "Semana 1: fluxo minimo concluido com sucesso."

sim: compile
	$(VVP) build/smoke.vvp

compile: lint | build
	$(IVERILOG) -g2012 -Wall -s tb_smoke_top -o build/smoke.vvp $(RTL) $(TB)

lint: check-tools
	$(VERILATOR) --lint-only -Wall --top-module smoke_top $(RTL)

build:
	mkdir -p build

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

# Uma receita compartilhada por suite; package sempre antes do consumidor.
define AES_TEST
.PHONY: test-aes-$(1) sim-aes-$(1) compile-aes-$(1) lint-aes-$(1)
test-aes-$(1): sim-aes-$(1)
sim-aes-$(1): compile-aes-$(1)
	$(VVP) build/aes_$(1).vvp
compile-aes-$(1): lint-aes-$(1) | build
	$(IVERILOG) -g2012 -Wall -s $(2)_tb -o build/aes_$(1).vvp $(3) tb/$(2)_tb.sv
lint-aes-$(1): check-tools
	$(VERILATOR) --lint-only -Wall --top-module $(2) $(3)
endef
$(eval $(call AES_TEST,dp,minisoc_aes_dp,$(AES_DP_RTL)))
$(eval $(call AES_TEST,key,minisoc_aes_key_exp,$(AES_KEY_RTL)))
$(eval $(call AES_TEST,core,minisoc_aes_core,$(AES_CORE_RTL)))

.PHONY: test-aes-transforms sim-aes-transforms compile-aes-transforms lint-aes-transforms
test-aes-transforms: sim-aes-transforms
sim-aes-transforms: compile-aes-transforms
	$(VVP) build/aes_transforms.vvp
compile-aes-transforms: lint-aes-transforms | build
	$(IVERILOG) -g2012 -Wall -s minisoc_aes_transforms_tb -o build/aes_transforms.vvp $(AES_TRANSFORMS_RTL) tb/minisoc_aes_transforms_tb.sv
lint-aes-transforms: check-tools
	$(VERILATOR) --lint-only -Wall --top-module minisoc_aes_sbox $(AES_PKG) rtl/minisoc_aes/minisoc_aes_sbox.sv
	$(VERILATOR) --lint-only -Wall --top-module minisoc_aes_sub_bytes $(AES_PKG) rtl/minisoc_aes/minisoc_aes_sub_bytes.sv
	$(VERILATOR) --lint-only -Wall --top-module minisoc_aes_shift_rows $(AES_PKG) rtl/minisoc_aes/minisoc_aes_shift_rows.sv

test-aes: test-aes-transforms test-aes-dp test-aes-key test-aes-core
regression: smoke test-aes

# Yosys/slang opcional; nao e dependencia de smoke/test-aes.
check-synth-tools:
	@command -v "$(YOSYS)" >/dev/null 2>&1 || { echo "ERRO: dependencia ausente: $(YOSYS)." >&2; exit 1; }

define AES_SYNTH
.PHONY: synth-aes-$(1)
synth-aes-$(1): check-synth-tools | build
	$(YOSYS) -m slang -Q -T -l build/aes_$(1)_synth.log -s scripts/synth_aes_$(1).ys
endef
$(foreach unit,dp key core,$(eval $(call AES_SYNTH,$(unit))))
synth-aes: synth-aes-dp synth-aes-key synth-aes-core

# Remove somente artefatos conhecidos; nunca faz exclusao recursiva.
# Nao execute clean e smoke como alvos concorrentes; use comandos separados.
clean:
	rm -f build/smoke.vvp build/aes_transforms.vvp build/aes_dp.vvp build/aes_key.vvp build/aes_core.vvp
