# Ubuntu + Btrfs + Automatic Snapshots

This script creates Btrfs subvolumes (while still in Live CD/USB mode) for Ubuntu 24.04 (or newer) and compatible derivatives.

## What the Script Does

- Creates Btrfs subvolumes:  
  - `@home` `@log` `@cache` `@tmp` `@libvirt` `@flatpak` `@docker` `@containers` `@machines` `@var_tmp` `@opt` 

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
     - 
Note: `/boot/efi` partition don't necessarily need to be created first. The `/boot` partition can be created first if the installer requires it.

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

```bash
sudo ./ubuntu-btrfs-install.sh sda3 sda2 sda1
```
This example is using `/dev/sda`

> Double-check your partition names using `lsblk -f`

### ✅ Done!

You can now reboot before installing Snapper and Btrfs Assistant for automatic snapshots.

💡 Tip: to view Btrfs subvolumes run:

```bash
sudo btrfs subvolume list /
```

## 📦 Manual Installation of Snapper and Btrfs Assistant (Post-Installation)
Snapper is a snapshot manager and Btrfs Assistant is a Snapper GUI.

After rebooting the system, install:

```bash
sudo apt update
sudo apt install -y snapper btrfs-assistant
```

Create Snapper root config:

```bash
sudo snapper -c root create-config /
```

Enable timeline and cleanup timers:

```bash
sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
```

You can now launch **Btrfs Assistant** from your application menu or run:

```bash
btrfs-assistant
```

### Automatic Snapshots Configuration 

1. Now go to **"Snapper Settings"** tab 🟢 **Enable timeline snapshots**:
   - Hourly save: 10
   - Daily save: 10
   - Weekly save: 0
   - Montthly save: 3
   - Yearly save: 1
   - Number save: 10
- System unit settings:

   * 🟢 Check **"Enable cleanup enabled"**
   * 🟢 Check **"Snapper timeline enabled"**
   * ❌ Keep unmarked **"Snapper boot"**
     - With a separate /boot on ext4, enabling Boot Snapshots is not recommended because:
     - They will have no real effect.
     - They may cause confusion or failures in system restores (since /boot will not be included in Btrfs snapshots).
     
2. Click **"Apply systemd changes"**.


### ✅ Done! Your system now has snapshots automatically.


### Screenshots

- Btrfs Assistant "Snapper"
![Btrfs Assistant Snapper](https://gitlab.com/-/project/32535488/uploads/65b6004c3257d66154828259a0fed47d/image.png)

- Btrfs Assistant "Snapper Settings"
![Btrfs Assistant Snapper Settings](https://gitlab.com/-/project/32535488/uploads/429be74e9fb92088697944d23a1def1d/image.png)

## License

MIT License — [View License](https://github.com/diogopessoa/ubuntu-btrfs-install/blob/main/LICENSE) You can use, modify, and contribute!

## Credits

* [openSUSE Team](https://github.com/openSUSE/snapper) — Snapper
* [Antynea](https://github.com/Antynea/grub-btrfs) — grub-btrfs
* [Dan Cantrell](https://gitlab.com/btrfs-assistant/btrfs-assistant) — Btrfs Assistant
* [Ubuntu](https://ubuntu.com/download) — Operating System
