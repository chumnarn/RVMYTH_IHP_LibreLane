# RTL sources

`mythcore_test.v` and the associated generated/include files retain their upstream RVMyth names and source. The integration boundary is `chip_core.sv`; the physical pad wrapper is `chip_top.sv`.

The full-chip padframe is for physical implementation. `make sim-rtl` simulates the upstream `core` directly, so pad behavioral models are not needed for the initial RTL smoke test.
