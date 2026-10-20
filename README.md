# RVMYTH full-chip implementation — IHP SG13G2 / LibreLane

Thai step-by-step manual: `docs/RVMYTH_Full_Chip_LibreLane_IHP_SG13G2_TH.md`

Quick start (from this directory):

```bash
nix develop
make clone-pdk
make sim-rtl
make librelane
```

`make librelane` writes final views under `final/` and keeps full logs/reports in `librelane/runs/`. Review DRC/LVS/timing and PG connectivity reports before treating any result as accepted. `make librelane-nodrc` is for debug only because it skips physical checks.

See `NOTICE.md` for upstream source provenance and licensing caveat.
