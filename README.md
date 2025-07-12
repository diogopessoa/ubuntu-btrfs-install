# Ubuntu + Btrfs + Automatic Snapshots

This script creates Btrfs subvolumes (while still in Live CD/USB mode) and configures automatic snapshots for Ubuntu 24.04 (or newer) and compatible derivatives.

## What the Script Does

- Creates Btrfs subvolumes:  
  - `@`, `@home`, `@log`, `@cache`, `@tmp`, `@libvirt`, `@flatpak`  
- Enables automatic snapshots  
- Adds snapshot entries to the GRUB boot menu  
- Installs and configures:  
  - `snapper` for managing snapshots  
  - `grub-btrfs` to integrate snapshots into GRUB  
  - `btrfs-assistant` (a GUI application for Snapper snapshot management)  

## Requirements

- Ubuntu 24.04 or newer installed with:  
  - Root filesystem using **Btrfs**  
  - Separate **/boot** partition formatted as ext4 (1GB)  
  - (Optional) EFI partition for UEFI systems (1GB)  
- Run the `ubuntu-btrfs-install` script from the **Live CD/USB** after Ubuntu is installed

## Install Ubuntu with Btrfs

This guide uses Ubuntu 25.04 as an example.

### Step-by-Step Guide

1. **Preparation**  
   - Create a bootable USB drive using the Ubuntu ISO  
   - Disable Secure Boot in BIOS/UEFI if needed to avoid installation issues  

2. **Start Installation**  
   - Boot from the USB drive and select your language  
   - Choose “Manual installation” (custom partitioning)  

3. **Create Partitions in the Correct Order**  
   - Create a new GPT partition table on the disk  
   - Create the **/boot/efi** partition:  
     - Size: 1GB  
     - Format: FAT32 (vfat)  
     - Type: EFI System Partition  
     - Mount point: `/boot/efi`  
   - Create the **/boot** partition:  
     - Size: 1GB  
     - Format: ext4  
     - Mount point: `/boot`  
   - Create the root **/** partition:  
     - Use all remaining space  
     - Format: Btrfs  
     - Mount point: `/`  

4. **Final Partition Table Should Look Like:**  
   - `/boot/efi` as FAT32 (vfat)  
   - `/boot` as ext4  
   - `/` as Btrfs  

5. **Complete Installation**  
   - Finish the Ubuntu installation, but **DO NOT reboot yet**

## How to Use the Script

⚠️ **After installing Ubuntu with Btrfs, do not reboot!**

### Identify Your Partitions

Run the following command in the terminal:

```bash
lsblk -f
````

Look for identifiers like `sda`, `nvme0n1`, etc. Example output:

```
sda     
├─sda1  vfat   /boot/efi
├─sda2  ext4   /boot
└─sda3  btrfs  /
```

### Download the Script to the Live Session

```bash
cd ~/Downloads
wget https://raw.githubusercontent.com/diogopessoa/ubuntu-btrfs-install/main/ubuntu-btrfs-install.sh
```

### Make It Executable

```bash
chmod +x ubuntu-btrfs-install.sh
```

### Run the Script

The argument order must be: `root` → `boot` → `efi`
Example using `/dev/sda`:

```bash
sudo ./ubuntu-btrfs-install.sh sda3 sda2 sda1
```

> Double-check your partition names using `lsblk -f`

### ✅ Done!

You can now reboot and enjoy Ubuntu with Btrfs and automatic snapshots.

💡 Tip: To view Btrfs subvolumes, open **Btrfs Assistant** → “Subvolumes” tab
Or run:

```bash
sudo btrfs subvolume list /
```

## License

MIT License — [View License](https://github.com/diogopessoa/ubuntu-btrfs-install/blob/main/LICENSE)

## Credits

* [openSUSE Team](https://github.com/openSUSE/snapper) — Snapper
* [Antynea](https://github.com/Antynea/grub-btrfs) — grub-btrfs
* [Dan Cantrell](https://gitlab.com/btrfs-assistant/btrfs-assistant) — Btrfs Assistant
* [Ubuntu](https://ubuntu.com/download) — Operating System
