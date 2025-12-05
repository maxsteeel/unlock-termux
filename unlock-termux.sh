#!/bin/bash

echo "Searching for OTG devices..."
DEVICE_PATH=$(termux-usb -l | grep -o '/dev/bus/usb/[^"]*' | head -n 1)

if [ -z "$DEVICE_PATH" ]; then
    echo "Error: No USB OTG device found."
    echo "Please ensure the device is connected correctly and try again."
    exit 1
fi

echo "Device found at: $DEVICE_PATH"

echo "Requesting access to the device. Please approve the permission prompt on your Android screen."
termux-usb -r "$DEVICE_PATH"

sleep 5

run_spd_dump() {
    termux-usb -e './spd_dump --usb-fd' "$DEVICE_PATH" "$@"
}

run_spd_dump exec_addr 0x65015f08 fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0x9efffe00 exec r splloader r uboot_a r uboot_b e splloader e splloader_bak reset

echo "(This is a notice, not an error.) Don't continue if you see 'find port failed'. Just close and re-run the script."
read -p "Press Enter to continue..."

./gen_spl-unlock splloader.bin

if [ $? -eq 0 ]; then
    if [ ! -f "u-boot-spl-16k-sign.bin" ]; then
        echo "Creating uboot backups..."
        mv "splloader.bin" "u-boot-spl-16k-sign.bin"
        
        ./chsize uboot_a.bin
        mv uboot_a.bin uboot_a_bak.bin
        
        ./chsize uboot_b.bin
        mv uboot_b.bin uboot_b_bak.bin
        echo "Backups created: u-boot-spl-16k-sign.bin, uboot_a_bak.bin, uboot_b_bak.bin"
    else
        echo "Backup files already exist. Skipping creation."
    fi
fi

read -p "Backup files generated. Press Enter to continue with flashing..."

run_spd_dump exec_addr 0x65015f08 fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0x9efffe00 exec w uboot_a fdl2-cboot.bin w uboot_b fdl2-cboot.bin reset

sleep 5

run_spd_dump exec_addr 0x65015f08 fdl spl-unlock.bin 0x65000800

echo "--- Verifying Unlock Status ---"
echo "If you get 64 zeros, it's locked. If you get a 32-char string + hash + hash, it's unlocked."
run_spd_dump exec_addr 0x65015f08 fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0x9efffe00 exec verbose 2 read_part miscdata 8192 64 m.bin reset
echo "Verification complete. Check the 'm.bin' file to confirm the status."

read -p "Press Enter to restore the original files..."
run_spd_dump exec_addr 0x65015f08 fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0x9efffe00 exec r boot_a r boot_b w splloader u-boot-spl-16k-sign.bin w uboot_a uboot_a_bak.bin w uboot_b uboot_b_bak.bin w misc misc-wipe.bin reset

echo "Process finished."
