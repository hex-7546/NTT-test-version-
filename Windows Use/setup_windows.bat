@echo off
REM ============================================================================
REM File: setup_windows.bat
REM Windows Setup Script for Kyber NTT Project
REM ============================================================================

echo ============================================
echo Kyber NTT Project - Windows Setup
echo ============================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo WARNING: Not running as administrator
    echo Some operations may fail
    echo.
)

REM Create directory structure
echo Creating directory structure...
if not exist build mkdir build
if not exist build\ip_repo mkdir build\ip_repo
if not exist rtl mkdir rtl
if not exist firmware mkdir firmware
if not exist scripts mkdir scripts
echo Done.
echo.

REM Check for required tools
echo Checking for required tools...

REM Check Python
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Python not found!
    echo Please install Python 3 from: https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during installation
    pause
    exit /b 1
) else (
    echo [OK] Python found
)

REM Check RISC-V toolchain
riscv-none-elf-gcc --version >nul 2>&1
if %errorLevel% neq 0 (
    riscv32-unknown-elf-gcc --version >nul 2>&1
    if %errorLevel% neq 0 (
        echo [WARNING] RISC-V toolchain not found!
        echo Please install from: https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases
        echo Add to PATH: C:\Program Files\riscv-toolchain\bin
        set MISSING_TOOLS=1
    ) else (
        echo [OK] RISC-V toolchain found (riscv32-unknown-elf)
    )
) else (
    echo [OK] RISC-V toolchain found (riscv-none-elf)
)

REM Check Vivado
vivado -version >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] Vivado not found!
    echo Please add Vivado to PATH: C:\Xilinx\Vivado\2025.1\bin
    set MISSING_TOOLS=1
) else (
    echo [OK] Vivado found
)

REM Check Make (optional)
make --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Make not found (optional)
    echo You can use Vivado GUI instead
) else (
    echo [OK] Make found
)

echo.

REM Download PicoRV32 if not present
if not exist rtl\picorv32.v (
    echo Downloading PicoRV32...
    powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/YosysHQ/picorv32/master/picorv32.v' -OutFile 'rtl\picorv32.v'"
    if %errorLevel% neq 0 (
        echo [ERROR] Failed to download PicoRV32!
        echo Please manually download from:
        echo https://raw.githubusercontent.com/YosysHQ/picorv32/master/picorv32.v
        echo and save to rtl\picorv32.v
        set MISSING_FILES=1
    ) else (
        echo [OK] PicoRV32 downloaded
    )
) else (
    echo [OK] PicoRV32 already exists
)

echo.
echo ============================================
echo Setup Summary
echo ============================================

if defined MISSING_TOOLS (
    echo [WARNING] Some required tools are missing
    echo Please install them before building
    echo See WINDOWS_GUIDE.md for instructions
) else (
    echo [OK] All required tools found
)

if defined MISSING_FILES (
    echo [WARNING] Some required files are missing
    echo Please download them manually
) else (
    echo [OK] All required files present
)

echo.
echo Next steps:
echo 1. Review WINDOWS_GUIDE.md for detailed instructions
echo 2. Build firmware: cd firmware ^&^& build_firmware.bat
echo 3. Open Vivado and follow GUI instructions
echo 4. Or use: make all (if Make is installed)
echo.
echo ============================================

pause