# Source notices

- RVMyth RTL and generated files are copied from https://github.com/kunalg123/rvmyth at commit `2037d3403dc6156ea1d1cc70af34886a3889ff36` for integration and study. The upstream snapshot does not contain a LICENSE file; confirm licensing with the upstream maintainer before redistribution beyond educational review.
- Padframe/configuration structure and Nix/LibreLane setup are adapted from https://github.com/chumnarn/ihp-sg13g2-librelane-template at commit `0418301723d86133de686ef743cfd668bb3d11d4`. That repository carries Apache-2.0; its LICENSE and AUTHORS.md are included.
- PDK files and IO cells are not bundled. `make clone-pdk` retrieves the PDK revision pinned in this package's Makefile.
