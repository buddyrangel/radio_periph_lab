
@echo off

:: Lab 10 - Custom AXI/AXIS Radio Peripheral
:: Johns Hopkins University - EN.525.742
:: Vivado Hardware Build Script

:: Run from the project root directory.
cd /d "%~dp0"

:: Check whether Vivado is already available.
where vivado >nul 2>&1
if not errorlevel 1 goto build

:: Check the professor's original installation path.
if exist "C:\AMDDesignTools\2025.2\Vivado\settings64.bat" (
    call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
    goto build
)

:: Check the local development installation path.
if exist "F:\AMD_Adaptive\2025.2\Vivado\settings64.bat" (
    call "F:\AMD_Adaptive\2025.2\Vivado\settings64.bat"
    goto build
)

echo ERROR: Vivado was not found.
echo Run this script from a Vivado command prompt,
echo or update the installation path.
exit /b 1

:build

:: Generate the Vivado project.
call vivado -nolog -nojournal -mode=batch -source=./tcl/make_project.tcl
if errorlevel 1 exit /b 1

:: Implement the design and generate the bitstream.
call vivado -nolog -nojournal -mode=batch -source=./tcl/impl.tcl
if errorlevel 1 exit /b 1

:: Vitis generation is not required for Linux testing.

:: Convert the bitstream into .bit.bin format.
call bootgen -image doug.bif -arch zynq -process_bitstream bin -w on
if errorlevel 1 exit /b 1

echo.
echo Lab 10 hardware build completed successfully.
