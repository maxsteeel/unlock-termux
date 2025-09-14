#!/bin/bash

# ==============================================================================
# Script for bootloader unlock on Spreadtrum devices using Termux
# Adapted to automatically detect and use OTG devices.
# ==============================================================================

# --- PREREQUISITES ---
# 1. Install dependencies: pkg install termux-api libusb
# 2. Ensure that the binaries (spd_dump, gen_spl-unlock, chsize, etc.) and
#    the .bin files (fdl1-dl.bin, etc.) are in the same folder as this script.
# 3. Connect the device in flash mode.
# ==============================================================================


# --- STEP 1: USB Device Detection and Authorization ---

echo "🔎 Searching for OTG devices..."
# termux-usb -l returns something like ["/dev/bus/usb/001/002"]
# We use grep and cut to extract the clean device path.
DEVICE_PATH=$(termux-usb -l | grep -o '/dev/bus/usb/[^"]*' | head -n 1)

if [ -z "$DEVICE_PATH" ]; then
    echo "❌ Error: No USB OTG device found."
    echo "Please ensure the device is connected correctly and try again."
    exit 1
fi

echo "✅ Device found at: $DEVICE_PATH"

echo "🔐 Requesting access to the device. Please approve the permission prompt on your Android screen."
termux-usb -r "$DEVICE_PATH"
# Add a small delay to allow the user to grant permission
sleep 3


# --- Helper function to run spd_dump ---
# This function simplifies executing commands via termux-usb.
run_spd_dump() {
    termux-usb -e './spd_dump --usb-fd' "$DEVICE_PATH" "$@"
}


# --- BLOCK 1: Initial read and erase ---
echo "--- Starting BLOCK 1: Read and Erase ---"
run_spd_dump exec_addr 0x65015f08 fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0x9efffe00 exec r splloader r uboot_a r uboot_b e splloader e splloader_bak reset

echo "(This is a notice, not an error.) Don't continue if you see 'find port failed'. Just close and re-run the script."
read -p "Press Enter to continue..."


# --- BLOCK 2: Generating and renaming backup files ---
echo "--- Starting BLOCK 2: Generating Backups ---"
./gen_spl-unlock splloader.bin

if [ $? -eq 0 ]; then
    if [ ! -f "u-boot-spl-16k-sign.bin" ]; then
        echo "Creating uboot backups..."
        mv "splloader.bin" "u-boot-spl-16k-sign.bin"
        
        # Restoring the chsize executable calls as requested.
        # Ensure 'chsize' is an executable file in this directory.
        ./chsize uboot_a.bin
        mv uboot_a.bin uboot_a_bak.bin
        
        ./chsize uboot_b.bin
        mv uboot_b.bin uboot_b_bak.bin
        echo "✅ Backups created: u-boot-spl-16k-sign.bin, uboot_a_bak.bin, uboot_b_bak.bin"
    else
        echo "ℹ️ Backup files already exist. Skipping creation."
    fi
fi

read -p "Backup files generated. Press Enter to continue with flashing..."


# --- BLOCK 3: Flashing cboot ---
echo "--- Starting BLOCK 3: Flashing cboot ---"
run_spd_dump exec_addr 0x65015f08 fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0x9efffe00 exec w uboot_a fdl2-cboot.bin w uboot_b fdl2-cboot.bin reset

echo "Waiting 10 seconds..."
sleep 10


# --- BLOCK 4: Unlock (may need to be run twice) ---
echo "--- Starting BLOCK 4: Executing Unlock ---"
run_spd_dump exec_addr 0x65015f08 fdl spl-unlock.bin 0x65000800


# --- BLOCK 5: Verifying the unlock ---
echo "--- Starting BLOCK 5: Verifying Unlock Status ---"
# If you get 64 zeros, it's locked. If you get a 32-char string + hash + hash, it's unlocked.
run_spd_dump exec_addr 0x65015f08 fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0x9efffe00 exec verbose 2 read_part miscdata 8192 64 m.bin reset
echo "Verification complete. Check the 'm.bin' file to confirm the status."

read -p "Press Enter to restore the original files..."


# --- BLOCK 6: Restoring spl and uboot ---
echo "--- Starting BLOCK 6: Restoring Partitions ---"
run_spd_dump exec_addr 0x65015f08 fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0x9efffe00 exec r boot_a r boot_b w splloader u-boot-spl-16k-sign.bin w uboot_a uboot_a_bak.bin w uboot_b uboot_b_bak.bin w misc misc-wipe.bin reset

echo "✅ Process finished."
