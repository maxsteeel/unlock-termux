# Unlock Unisoc-based phones with termux

Script for bootloader unlock on Spreadtrum devices using Termux
Adapted to automatically detect and use OTG devices.


#  Instructions:

1. Install dependencies:
 ```
 pkg install termux-api libusb git
 ```
2. Clone this repo:
```
git clone https://github.com/maxsteeel/unlock-termux
```
3. Connect the device in flash mode.

4. Run the script
```
cd unlock-termux
bash unlock-termux.sh
```
