@echo off
setlocal
cd /d "%~dp0"

set "VIVADO_CMD="
where vivado.bat >nul 2>&1
if not errorlevel 1 set "VIVADO_CMD=vivado.bat"

if not defined VIVADO_CMD if defined XILINX_VIVADO if exist "%XILINX_VIVADO%\bin\vivado.bat" set "VIVADO_CMD=%XILINX_VIVADO%\bin\vivado.bat"
if not defined VIVADO_CMD if exist "C:\Xilinx\2025.1\Vivado\bin\vivado.bat" set "VIVADO_CMD=C:\Xilinx\2025.1\Vivado\bin\vivado.bat"
if not defined VIVADO_CMD if exist "C:\Xilinx\Vivado\2025.1\bin\vivado.bat" set "VIVADO_CMD=C:\Xilinx\Vivado\2025.1\bin\vivado.bat"
if not defined VIVADO_CMD if exist "C:\AMD\Vivado\2025.1\bin\vivado.bat" set "VIVADO_CMD=C:\AMD\Vivado\2025.1\bin\vivado.bat"

if not defined VIVADO_CMD (
    echo ERROR: Vivado was not found.
    echo Start a Vivado command prompt and run this file again, or set XILINX_VIVADO.
    pause
    exit /b 1
)

set "PROJECT_FILE=vivado\basys3_adaptive_traffic_controller.xpr"
if not exist "%PROJECT_FILE%" (
    echo Creating the Vivado project...
    call "%VIVADO_CMD%" -mode batch -source scripts\create_vivado_project.tcl -notrace
    if errorlevel 1 (
        echo ERROR: Vivado project creation failed.
        pause
        exit /b 1
    )
)

echo Opening %PROJECT_FILE%...
call "%VIVADO_CMD%" "%PROJECT_FILE%"
endlocal
