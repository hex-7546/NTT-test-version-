# NTT test version
# Kyber512 NTT Accelerator for Arty A7-100T

Complete hardware-accelerated Number Theoretic Transform (NTT) implementation for CRYSTALS-Kyber512 post-quantum cryptography on FPGA.

## Project Structure

```
kyber_ntt_project/
├── README.md                   # This file
├── WINDOWS_GUIDE.md           # Windows-specific instructions
├── Makefile                   # Build automation
├── rtl/                       # Verilog HDL files
│   ├── top.v                  # Top-level module
│   ├── ntt_core.v            # NTT accelerator core
│   ├── ntt_wrapper.v         # Memory-mapped wrapper
│   ├── twiddle_rom.v         # Twiddle factor ROM
│   ├── memory_modules.v      # ROM and RAM
│   ├── uart.v                # UART module
│   ├── arty_a7.xdc           # Constraints file
│   └── picorv32.v            # Download separately
├── firmware/                  # C firmware
│   ├── firmware.c            # Main firmware code
│   └── linker.ld             # Linker script
├── scripts/                   # Build scripts
│   ├── bin2hex.py            # Binary to hex converter
│   ├── build_vivado.tcl      # Vivado build script
│   └── program.tcl           # Programming script
└── build/                     # Generated files (created during build)
```

## Features

- ✅ Hardware NTT/INTT for n=256, q=3329 (Kyber512 parameters)
- ✅ 2 parallel butterfly units for balanced performance
- ✅ Memory-mapped interface at 0x10000000
- ✅ PicoRV32 RISC-V processor for control
- ✅ Complete test suite with UART output
- ✅ ~70 μs per NTT @ 50 MHz
- ✅ Only 5.5% LUT, 26% BRAM utilization

## Prerequisites

### Hardware
- Digilent Arty A7-100T FPGA board
- USB cable for programming and UART

### Software (Windows or Linux)

1. **Xilinx Vivado 2025.1** (or compatible version)
   - Download from: https://www.xilinx.com/support/download.html

2. **RISC-V GNU Toolchain**
   - **Windows**: Download from https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases
   - **Linux**: `sudo apt-get install gcc-riscv64-unknown-elf`

3. **Python 3.x**
   - **Windows**: https://www.python.org/downloads/
   - **Linux**: Usually pre-installed

4. **Make** (optional but recommended)
   - **Windows**: Install from http://gnuwin32.sourceforge.net/packages/make.htm or use WSL
   - **Linux**: Usually pre-installed

5. **Serial Terminal**
   - **Windows**: PuTTY, TeraTerm, or RealTerm
   - **Linux**: minicom, screen, or picocom

## Quick Start

### 1. Download PicoRV32

```bash
# Navigate to rtl directory
cd rtl

# Download PicoRV32
# Windows PowerShell:
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/YosysHQ/picorv32/master/picorv32.v" -OutFile "picorv32.v"

# Linux/macOS:
wget https://raw.githubusercontent.com/YosysHQ/picorv32/master/picorv32.v
```

### 2. Build the Project

#### Using Make (Linux/Windows with Make)

```bash
# Build everything
make all

# Or build step by step
make firmware    # Compile firmware
make bitstream   # Build FPGA bitstream
```

#### Using Vivado GUI (Windows)

See [WINDOWS_GUIDE.md](WINDOWS_GUIDE.md) for detailed GUI instructions.

### 3. Program the FPGA

#### Using Make

```bash
make program
```

#### Using Vivado Hardware Manager

1. Open Vivado
2. Click "Open Hardware Manager"
3. Click "Open Target" → "Auto Connect"
4. Right-click on the device → "Program Device"
5. Select `build/kyber_ntt.bit`
6. Click "Program"

### 4. Connect UART and View Output

#### Windows (PuTTY)

1. Open PuTTY
2. Connection type: Serial
3. Serial line: COM3 (check Device Manager)
4. Speed: 115200
5. Click "Open"

#### Linux

```bash
minicom -D /dev/ttyUSB1 -b 115200
# or
screen /dev/ttyUSB1 115200
```

### 5. Expected Output

```
=====================================
  Kyber512 NTT Accelerator Demo
  PicoRV32 + Hardware NTT
=====================================

System initialized!
Clock: 50 MHz
NTT Base: 0x10000000

=== Testing NTT/INTT Round-Trip ===
Original: [42, 84, 126, 168, 210, 252, 294, 336...]
Performing NTT...
NTT: [2145, 1892, 3201, ...]
Performing INTT...
INTT: [42, 84, 126, 168, 210, 252, 294, 336...]
SUCCESS: NTT/INTT round-trip verified!

=== Testing Polynomial Multiplication ===
...
SUCCESS: Polynomial multiplication completed!

=== NTT Performance Benchmark ===
NTT cycles: 3456
INTT cycles: 3521

=====================================
  ALL TESTS PASSED!
=====================================
```

## Memory Map

| Address Range | Component | Description |
|---------------|-----------|-------------|
| 0x00000000 - 0x00003FFF | ROM | 16KB program memory |
| 0x00010000 - 0x00013FFF | RAM | 16KB data memory |
| 0x10000000 | NTT Control | Start, mode register |
| 0x10000004 | NTT Status | Busy, done, error flags |
| 0x10000100 - 0x100002FF | NTT Coefficients | 256 × 16-bit values |
| 0x20000000 | UART Data | TX/RX data |
| 0x20000004 | UART Status | TX ready, RX valid |

## Hardware Architecture

```
┌─────────────────────────────────────────────┐
│          Arty A7-100T FPGA                  │
│                                             │
│  ┌──────────┐       ┌──────────────┐       │
│  │PicoRV32  │◄─────►│   Memory     │       │
│  │(50 MHz)  │       │  Controller  │       │
│  └──────────┘       └──────┬───────┘       │
│                             │               │
│  ┌──────────────────────────┼─────────────┐ │
│  │         Memory Bus       ▼             │ │
│  │  ┌───────┐ ┌───────┐ ┌──────────┐    │ │
│  │  │ ROM   │ │ RAM   │ │   UART   │    │ │
│  │  │ 16KB  │ │ 16KB  │ │          │    │ │
│  │  └───────┘ └───────┘ └──────────┘    │ │
│  │                                       │ │
│  │  ┌─────────────────────────────────┐ │ │
│  │  │    NTT Accelerator              │ │ │
│  │  │  ┌─────────┐  ┌─────────┐      │ │ │
│  │  │  │Butterfly│  │Butterfly│      │ │ │
│  │  │  │ Unit 0  │  │ Unit 1  │      │ │ │
│  │  │  └─────────┘  └─────────┘      │ │ │
│  │  │  ┌─────────────────────────┐   │ │ │
│  │  │  │  Coefficient Memory     │   │ │ │
│  │  │  │  (256 × 16-bit)         │   │ │ │
│  │  │  └─────────────────────────┘   │ │ │
│  │  │  ┌─────────────────────────┐   │ │ │
│  │  │  │  Twiddle Factor ROM     │   │ │ │
│  │  │  └─────────────────────────┘   │ │ │
│  │  └─────────────────────────────────┘ │ │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## Resource Utilization

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | ~3,500 | 63,400 | 5.5% |
| FFs | ~2,200 | 126,800 | 1.7% |
| BRAM | ~35 | 135 | 26% |
| DSP | ~8 | 240 | 3.3% |

## Performance

| Operation | Cycles | Time (μs) @ 50 MHz | Throughput |
|-----------|--------|--------------------|------------|
| NTT-256 | ~3,500 | ~70 | 14,285 ops/s |
| INTT-256 | ~3,500 | ~70 | 14,285 ops/s |
| Poly Multiply | ~7,500 | ~150 | 6,667 ops/s |

## Troubleshooting

### Build Issues

**Problem**: "picorv32.v not found"
- **Solution**: Download picorv32.v and place in rtl/ directory (see Quick Start #1)

**Problem**: RISC-V toolchain not found
- **Solution**: Install toolchain and add to PATH
  - Windows: Add installation directory to System Environment Variables
  - Linux: Add to ~/.bashrc: `export PATH=/opt/riscv/bin:$PATH`

**Problem**: Vivado not found
- **Solution**: Add Vivado to PATH
  - Windows: `C:\Xilinx\Vivado\2025.1\bin`
  - Linux: Source settings: `source /tools/Xilinx/Vivado/2025.1/settings64.sh`

### Hardware Issues

**Problem**: FPGA not detected
- Check USB cable connection
- Install Digilent Cable Drivers from Vivado
- Try different USB port

**Problem**: No UART output
- Verify COM port in Device Manager (Windows) or `ls /dev/ttyUSB*` (Linux)
- Check baud rate: 115200
- Reset board after connecting terminal

**Problem**: LEDs not working
- Verify bitstream programmed successfully
- LED[0] should blink (heartbeat)
- LED[1] should be solid ON (system ready)

## Customization

### Modify Firmware

Edit `firmware/firmware.c` to add custom operations:

```c
// Example: Custom NTT operation
void my_custom_function() {
    int16_t poly[KYBER_N];
    
    // Generate or load polynomial
    generate_test_poly(poly, 42);
    
    // Transform to NTT domain
    ntt_forward(poly);
    
    // Process in NTT domain
    // ...
    
    // Transform back
    ntt_inverse(poly);
}
```

### Increase Performance

To add more butterfly units, edit `rtl/ntt_core.v`:
- Change parameter for number of butterfly units
- Adjust FSM to handle parallel operations

### Change Clock Frequency

Edit scripts/build_vivado.tcl:
```tcl
CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000}  # Change to 100 MHz
```

## References

- [CRYSTALS-Kyber Specification](https://pq-crystals.org/kyber/)
- [PicoRV32 Documentation](https://github.com/YosysHQ/picorv32)
- [Arty A7 Reference Manual](https://digilent.com/reference/programmable-logic/arty-a7/)

## License

This project is provided as educational material. See individual component licenses:
- PicoRV32: ISC License
- Kyber algorithms: Public domain

## Support

For issues:
1. Check [WINDOWS_GUIDE.md](WindowsUse/WINDOWS_GUIDE.md) for Windows-specific help
2. Verify all prerequisites are installed
3. Check UART connection and baud rate

## Authors

- Yash Mahto
- Based on CRYSTALS-Kyber reference implementation
- PicoRV32 by Claire Wolf (YosysHQ)

---

**Last Updated**: 2025-01-27
**Tested On**: Arty A7-100T with Vivado 2025.1
