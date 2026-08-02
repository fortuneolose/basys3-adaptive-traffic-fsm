# Vivado project directory

Run `launch_vivado_project.bat` on Windows or `launch_vivado_project.sh` on
Linux/WSL. The launcher generates
`basys3_adaptive_traffic_controller.xpr` here and opens it in Vivado.

The `.xpr` and Vivado-managed subdirectories are generated rather than bundled
so the project remains portable across installation paths and Vivado patch
versions. The repository-owned RTL, testbench and constraint files remain in
their existing top-level directories.
