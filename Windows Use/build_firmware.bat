@echo off
REM ============================================================================
REM File: firmware/build_firmware.bat
REM Build firmware on Windows
REM ============================================================================

echo ============================================
echo Building Firmware
echo ============================================
echo.

REM Create build directory if it doesn't exist
if not exist ..\build mkdir ..\build

REM Detect RISC-V toolchain prefix
set RISCV_PREFIX=
riscv-none-elf-gcc --version >nul 2>&1
if %errorLevel% == 0 (
    set RISCV_PREFIX=riscv-none-elf-
    echo Using toolchain: riscv-none-elf
) else (
    riscv32-unknown-elf-gcc --version >nul 2>&1
    if %errorLevel% == 0 (
        set RISCV_PREFIX=riscv32-unknown-elf-
        echo Using toolchain: riscv32-unknown-elf
    ) else (
        echo ERROR: RISC-V toolchain not found!
        echo Please install from: https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases
        pause
        exit /b 1
    )
)

echo.
echo Step 1: Compiling C code...
%RISCV_PREFIX%gcc -march=rv32i -mabi=ilp32 -Os -Wall -Wextra ^
    -ffreestanding -nostdlib -nostartfiles ^
    -fno-builtin -fno-exceptions ^
    -T linker.ld -o ..\build\firmware.elf firmware.c

if %errorLevel% neq 0 (
    echo ERROR: Compilation failed!
    pause
    exit /b 1
)
echo [OK] Compilation successful

echo.
echo Step 2: Creating binary...
%RISCV_PREFIX%objcopy -O binary ..\build\firmware.elf ..\build\firmware.bin

if %errorLevel% neq 0 (
    echo ERROR: Binary creation failed!
    pause
    exit /b 1
)
echo [OK] Binary created

echo.
echo Step 3: Creating hex file...
python ..\scripts\bin2hex.py ..\build\firmware.bin ..\build\firmware.hex

if %errorLevel% neq 0 (
    echo ERROR: Hex file creation failed!
    pause
    exit /b 1
)
echo [OK] Hex file created

echo.
echo Step 4: Creating disassembly...
%RISCV_PREFIX%objdump -d ..\build\firmware.elf > ..\build\firmware.dis
echo [OK] Disassembly created

echo.
echo Firmware size:
%RISCV_PREFIX%size ..\build\firmware.elf

echo.
echo ============================================
echo Build Complete!
echo ============================================
echo.
echo Generated files:
echo   build\firmware.elf - Executable
echo   build\firmware.bin - Binary
echo   build\firmware.hex - Hex for Vivado
echo   build\firmware.dis - Disassembly
echo.
echo Next step: Run Vivado synthesis
echo.

pause