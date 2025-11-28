# ============================================================================
# File: scripts/program.tcl
# Vivado Programming Script
# Programs the FPGA with the generated bitstream
# ============================================================================

set bitstream_file [lindex $argv 0]

if {![file exists $bitstream_file]} {
    puts "ERROR: Bitstream file not found: $bitstream_file"
    exit 1
}

puts "Programming FPGA with: $bitstream_file"

# Open hardware manager
open_hw_manager

# Connect to hardware server
connect_hw_server -allow_non_jtag

# Open target
open_hw_target

# Get the device
set device [lindex [get_hw_devices] 0]
puts "Target device: $device"

# Set programming file
current_hw_device $device
set_property PROGRAM.FILE $bitstream_file $device

# Program device
puts "Programming device..."
program_hw_devices $device

# Refresh device
refresh_hw_device $device

puts "Programming complete!"

# Close connections
close_hw_target
disconnect_hw_server
close_hw_manager