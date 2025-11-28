# Windows-Specific Setup Guide

Complete guide for building and running the Kyber512 NTT project on Windows with Vivado 2025.1.

## Prerequisites Installation (Windows)

### 1. Install Vivado 2025.1

1. Download Vivado from: https://www.xilinx.com/support/download.html
2. Run installer and select:
   - ☑ Vivado ML Edition
   - ☑ Artix-7 device support
3. Default installation path: `C:\Xilinx\Vivado\2025.1\`
4. Add to PATH:
   - Open "Environment Variables"
   - Add to System PATH: `C:\Xilinx\Vivado\2025.1\bin`

### 2. Install RISC-V Toolchain

**Option A: Pre-built (Recommended)**

1. Download from: https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases
2. Get: `xpack-riscv-none-elf-gcc-13.2.0-2-win32-x64.zip`
3. Extract to: `C:\Program Files\riscv-toolchain\`
4. Add to PATH: `C:\Program Files\riscv-toolchain\bin`
5. Verify installation:
   ```cmd
   riscv-none-elf-gcc --version
   ```

**Note**: The toolchain uses prefix `riscv-none-elf-` instead of `riscv32-unknown-elf-`. You'll need to either:
- Create symbolic links, OR
- Edit the Makefile (see below)

**Option B: Update Makefile for Windows**

Edit `Makefile` and change:
```makefile
# Change this line:
RISCV_PREFIX = riscv32-unknown-elf-

# To this:
RISCV_PREFIX = riscv-none-elf-
```

### 3. Install Python 3

1. Download from: https://www.python.org/downloads/
2. Run installer
3. ☑ Check "Add Python to PATH"
4. Install to default location
5. Verify:
   ```cmd
   python --version
   ```

### 4. Install Make (Optional)

**Option A: Using Chocolatey**
```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install make
```

**Option B: Manual Installation**
1. Download from: http://gnuwin32.sourceforge.net/packages/make.htm
2. Install to `C:\Program Files (x86)\GnuWin32\`
3. Add to PATH: `C:\Program Files (x86)\GnuWin32\bin`

**Option C: Use WSL (Windows Subsystem for Linux)**
```powershell
wsl --install
# Then use Linux commands inside WSL
```

### 5. Install Serial Terminal

**Option A: PuTTY (Recommended)**
1. Download from: https://www.putty.org/
2. Install to default location

**Option B: TeraTerm**
1. Download from: https://ttssh2.osdn.jp/
2. Install and configure for 115200 baud

## Building with Vivado GUI (Recommended for Windows)

### Step 1: Download PicoRV32

```powershell
# Open PowerShell in project directory
cd rtl
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/YosysHQ/picorv32/master/picorv32.v" -OutFile "picorv32.v"
cd ..
```

### Step 2: Compile Firmware

```cmd
# Open Command Prompt in project directory
cd firmware
riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -Os -Wall -Wextra ^
    -ffreestanding -nostdlib -nostartfiles ^
    -fno-builtin -fno-exceptions ^
    -T linker.ld -o ..\build\firmware.elf firmware.c

riscv-none-elf-objcopy -O binary ..\build\firmware.elf ..\build\firmware.bin

cd ..
python scripts\bin2hex.py build\firmware.bin build\firmware.hex
```

### Step 3: Create Vivado Project (GUI)

1. **Launch Vivado**
   ```cmd
   vivado
   ```

2. **Create New Project**
   - Click "Create Project"
   - Project name: `kyber_ntt`
   - Location: `<your_path>\build`
   - Click "Next"
   - Project type: "RTL Project"
   - ☑ "Do not specify sources at this time"
   - Click "Next"

3. **Select Part**
   - Parts
   - Search: `xc7a100tcsg324-1`
   - Select: Artix-7 xc7a100tcsg324-1
   - Click "Next", then "Finish"

4. **Add Source Files**
   - Click "Add Sources" (Alt+A)
   - Select "Add or create design sources"
   - Click "Add Files"
   - Navigate to `rtl\` directory
   - Select all `.v` files:
     - top.v
     - ntt_core.v
     - ntt_wrapper.v
     - twiddle_rom.v
     - memory_modules.v
     - uart.v
     - picorv32.v
   - Click "OK"

5. **Add Constraints**
   - Click "Add Sources"
   - Select "Add or create constraints"
   - Add file: `rtl\arty_a7.xdc`
   - Click "OK"

6. **Add Firmware**
   - Click "Add Sources"
   - Select "Add or create simulation sources"
   - Add file: `build\firmware.hex`
   - Set file type: "Memory Initialization Files"
   - Click "OK"

7. **Set Top Module**
   - In Sources window, right-click "top"
   - Select "Set as Top"

### Step 4: Create Clock Wizard IP

1. **IP Catalog**
   - Click "IP Catalog" in Flow Navigator
   - Search: "Clock Wizard"
   - Double-click "Clocking Wizard"

2. **Configure IP**
   - Component Name: `clk_wiz_0`
   - **Clocking Options**:
     - Primary Input Clock: 100 MHz
   - **Output Clocks**:
     - clk_out1: 50 MHz
     - ☑ Use locked
     - ☑ Use reset (Active High)
   - Click "OK"
   - Click "Generate"

### Step 5: Run Synthesis

1. Click "Run Synthesis" in Flow Navigator
2. Wait for completion (may take 10-20 minutes)
3. When complete, click "Open Synthesized Design"
4. Review reports:
   - Reports → Utilization
   - Reports → Timing

### Step 6: Run Implementation

1. Click "Run Implementation" in Flow Navigator
2. Wait for completion (may take 15-30 minutes)
3. When complete, click "Open Implemented Design"
4. Check timing:
   - Reports → Timing Summary
   - Verify WNS (Worst Negative Slack) is positive

### Step 7: Generate Bitstream

1. Click "Generate Bitstream" in Flow Navigator
2. Wait for completion (may take 5-10 minutes)
3. Bitstream saved to:
   ```
   build\kyber_ntt\kyber_ntt.runs\impl_1\top.bit
   ```

### Step 8: Program FPGA

1. Connect Arty A7-100T via USB
2. Power on the board
3. In Vivado:
   - Click "Open Hardware Manager"
   - Click "Open Target" → "Auto Connect"
   - Wait for device detection
   - Right-click on device (xc7a100t_0)
   - Select "Program Device"
   - Bitstream file: Browse to `impl_1\top.bit`
   - Click "Program"

### Step 9: Connect UART

1. **Find COM Port**
   - Open Device Manager
   - Expand "Ports (COM & LPT)"
   - Look for "USB Serial Port (COMx)" where x is a number
   - Note the COM port number (e.g., COM3)

2. **Open PuTTY**
   - Connection type: Serial
   - Serial line: COM3 (or your COM port)
   - Speed: 115200
   - Click "Open"

3. **Reset Board**
   - Press the reset button (BTN0) on Arty board
   - You should see output in PuTTY

## Building with Command Line (Advanced)

### Using PowerShell

```powershell
# Set environment
$env:PATH = "C:\Xilinx\Vivado\2025.1\bin;$env:PATH"

# Build firmware
cd firmware
& riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -Os -Wall -Wextra `
    -ffreestanding -nostdlib -nostartfiles `
    -fno-builtin -fno-exceptions `
    -T linker.ld -o ..\build\firmware.elf firmware.c

& riscv-none-elf-objcopy -O binary ..\build\firmware.elf ..\build\firmware.bin
cd ..

# Convert to hex
python scripts\bin2hex.py build\firmware.bin build\firmware.hex

# Run Vivado build
vivado -mode batch -source scripts\build_vivado.tcl `
    -tclargs kyber_ntt xc7a100tcsg324-1 top
```

### Using WSL

If you have WSL installed, you can use Linux commands:

```bash
# Inside WSL
cd /mnt/c/Users/YourName/kyber_ntt_project
make all
```

## Common Windows Issues

### Issue 1: "Command not found" errors

**Problem**: Tools not in PATH

**Solution**:
1. Open System Properties → Environment Variables
2. Edit "Path" in System variables
3. Add these paths (adjust versions as needed):
   ```
   C:\Xilinx\Vivado\2025.1\bin
   C:\Program Files\riscv-toolchain\bin
   C:\Python311
   C:\Python311\Scripts
   ```
4. Restart Command Prompt/PowerShell

### Issue 2: Long path issues

**Problem**: "Path too long" errors

**Solution 1**: Enable long paths in Windows 10/11
```powershell
# Run as Administrator
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
    -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

**Solution 2**: Use shorter project path
- Move project to `C:\kyber\` instead of long paths

### Issue 3: Vivado TCL script errors

**Problem**: Forward slashes in paths

**Solution**: TCL scripts work with forward slashes on Windows. If you see errors, ensure paths use forward slashes:
```tcl
# Good
add_files rtl/top.v

# Bad (on Windows TCL)
add_files rtl\top.v
```

### Issue 4: UART not working

**Problem**: COM port not found

**Solution 1**: Install Digilent Drivers
1. Open Vivado
2. Help → Add Design Tools or Devices
3. Install Digilent Cable Drivers

**Solution 2**: Check Device Manager
- If you see "Unknown Device" under "Other devices"
- Right-click → Update Driver
- Browse to: `C:\Xilinx\Vivado\2025.1\data\xicom\cable_drivers\nt64\digilent`

### Issue 5: Permission denied errors

**Problem**: File access denied

**Solution**:
1. Run Command Prompt as Administrator, OR
2. Disable antivirus temporarily during build, OR
3. Add project directory to antivirus exclusions

## Performance Tips

1. **Use SSD**: Place project on SSD for faster builds
2. **Close other apps**: Vivado uses significant RAM
3. **Increase swap**: Ensure at least 16GB total memory (RAM + swap)
4. **Multicore**: Vivado will use all CPU cores automatically

## Verification Checklist

Before asking for help, verify:

- [ ] Vivado 2025.1 installed and in PATH
- [ ] RISC-V toolchain installed and in PATH
- [ ] Python 3 installed and in PATH
- [ ] picorv32.v downloaded to rtl/ directory
- [ ] Firmware compiles without errors
- [ ] firmware.hex exists in build/ directory
- [ ] Vivado project opens without errors
- [ ] Synthesis completes successfully
- [ ] Implementation meets timing
- [ ] Bitstream generated successfully
- [ ] FPGA detected in Hardware Manager
- [ ] Programming completes without errors
- [ ] COM port detected in Device Manager
- [ ] PuTTY configured for 115200 baud
- [ ] UART shows output after reset

## Next Steps

After successful build:
1. Experiment with firmware modifications
2. Try different NTT parameters
3. Add custom polynomial operations
4. Integrate into larger Kyber implementation

## Support

For Windows-specific issues:
1. Check Windows Event Viewer for system errors
2. Review Vivado log files in `build\` directory
3. Verify all paths use forward slashes in TCL scripts
4. Try shorter project paths (closer to C:\)

---

**Tested On**: Windows 10/11 with Vivado 2025.1