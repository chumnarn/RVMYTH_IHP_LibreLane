PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PDK_ROOT ?= $(PROJECT_DIR)/IHP-Open-PDK
PDK ?= ihp-sg13g2
PDK_COMMIT ?= 3b5a704ba6738aa686b08706187830e6284d2a10
RUN_TAG = $(shell ls librelane/runs/ 2>/dev/null | sort | tail -n 1)

.DEFAULT_GOAL := help
.PHONY: help clone-pdk sim-rtl librelane librelane-nodrc openroad klayout copy-final clean
help:
	@echo 'Targets: clone-pdk sim-rtl librelane librelane-nodrc openroad klayout copy-final clean'
clone-pdk:
	ciel enable $(PDK_COMMIT) --pdk-root $(PDK_ROOT) --pdk-family $(PDK)
sim-rtl:
	iverilog -g2012 -I src -s tb_rvmyth_core -o build_rvmyth_sim src/mythcore_test.v src/tb_rvmyth_core.sv
	vvp build_rvmyth_sim
librelane:
	librelane librelane/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/
librelane-nodrc:
	librelane librelane/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ --skip KLayout.DRC --skip Magic.DRC --skip KLayout.Antenna --skip KLayout.Density
openroad:
	librelane librelane/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --last-run --flow OpenInOpenROAD
klayout:
	librelane librelane/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --last-run --flow OpenInKLayout
copy-final:
	@test -d final || (echo 'No saved final views; run make librelane first'; exit 1)
	@find final -maxdepth 2 -type f | sort
clean:
	rm -rf build_rvmyth_sim final
