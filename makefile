# ============================================================================
# File: Makefile
# Makefile for Kyber512 NTT Project (Cross-platform: Linux & Windows)
# ============================================================================

PROJECT_NAME = kyber_ntt
FPGA_PART = xc7a100tcsg324-1
TOP_MODULE = top

# Directories
RTL_DIR = rtl
FW_DIR = firmware
BUILD_DIR = build
SCRIPTS_DIR = scripts

# Vivado settings (adjust for Windows if needed)
ifeq ($(OS),Windows_NT)
    # Windows paths - adjust to your Vivado installation
    VIVADO = vivado.bat
    PYTHON = python
    RM = del /Q
    RMDIR = rmdir /S /Q
    MKDIR = mkdir
else
    # Linux/macOS
    VIVADO = vivado
    PYTHON = python3
    RM = rm -f
    RMDIR = rm -rf
    MKDIR = mkdir -p
endif

# RISC-V toolchain
RISCV_PREFIX = riscv32-unknown-elf-
CC = $(RISCV_PREFIX)gcc
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump
SIZE = $(RISCV_PREFIX)size

# Compiler flags
CFLAGS = -march=rv32i -mabi=ilp32 -Os -Wall -Wextra
CFLAGS += -ffreestanding -nostdlib -nostartfiles
CFLAGS += -fno-builtin -fno-exceptions
LDFLAGS = -T $(FW_DIR)/linker.ld -nostdlib -Wl,--gc-sections

# Source files
RTL_SOURCES = $(RTL_DIR)/top.v \
              $(RTL_DIR)/ntt_core.v \
              $(RTL_DIR)/ntt_wrapper.v \
              $(RTL_DIR)/twiddle_rom.v \
              $(RTL_DIR)/memory_modules.v \
              $(RTL_DIR)/uart.v

CONSTRAINTS = $(RTL_DIR)/arty_a7.xdc

FW_SOURCES = $(FW_DIR)/firmware.c

.PHONY: all clean firmware bitstream program help

all: firmware bitstream

# ============================================================================
# Firmware Build
# ============================================================================

firmware: $(BUILD_DIR)/firmware.hex

$(BUILD_DIR)/firmware.elf: $(FW_SOURCES) $(FW_DIR)/linker.ld
	@echo "Building firmware..."
	@$(MKDIR) $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(FW_SOURCES)
	@echo "Firmware size:"
	@$(SIZE) $@

$(BUILD_DIR)/firmware.bin: $(BUILD_DIR)/firmware.elf
	@echo "Creating binary..."
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/firmware.hex: $(BUILD_DIR)/firmware.bin
	@echo "Creating hex file..."
	$(PYTHON) $(SCRIPTS_DIR)/bin2hex.py $< $@
	@echo "Firmware hex file created: $@"

$(BUILD_DIR)/firmware.dis: $(BUILD_DIR)/firmware.elf
	@echo "Creating disassembly..."
	$(OBJDUMP) -d $< > $@

# ============================================================================
# FPGA Bitstream Build
# ============================================================================

bitstream: $(BUILD_DIR)/$(PROJECT_NAME).bit

$(BUILD_DIR)/$(PROJECT_NAME).bit: $(RTL_SOURCES) $(CONSTRAINTS) $(BUILD_DIR)/firmware.hex
	@echo "Building bitstream with Vivado..."
	@$(MKDIR) $(BUILD_DIR)
	$(VIVADO) -mode batch -source $(SCRIPTS_DIR)/build_vivado.tcl \
		-tclargs $(PROJECT_NAME) $(FPGA_PART) $(TOP_MODULE)
	@echo "Bitstream created: $@"

# ============================================================================
# Programming
# ============================================================================

program: $(BUILD_DIR)/$(PROJECT_NAME).bit
	@echo "Programming FPGA..."
	$(VIVADO) -mode batch -source $(SCRIPTS_DIR)/program.tcl -tclargs $<

# ============================================================================
# Utilities
# ============================================================================

clean:
	$(RMDIR) $(BUILD_DIR)
	$(RM) *.log *.jou *.str
	$(RMDIR) .Xil

help:
	@echo "Kyber512 NTT Project Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build firmware and bitstream (default)"
	@echo "  firmware   - Compile firmware only"
	@echo "  bitstream  - Build FPGA bitstream"
	@echo "  program    - Program FPGA with bitstream"
	@echo "  clean      - Remove build artifacts"
	@echo "  help       - Show this help"
	@echo ""
	@echo "Requirements:"
	@echo "  - Vivado 2025.1"
	@echo "  - RISC-V GNU Toolchain ($(RISCV_PREFIX))"
	@echo "  - Python 3"