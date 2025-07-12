#!/bin/bash
# Author: Diogo Pessoa (https://github.com/diogopessoa)
# License: MIT
# Description: This script configures Ubuntu with Btrfs by creating subvolumes,
#              adjusting fstab, and setting up Snapper, grub-btrfs, and Btrfs Assistant.

set -e

script=$(readlink -f "$0")
scriptname=$(basename "$script")
[ $(id -u) -eq 0 ] || { echo "ERROR: This script must be run as root."; exit 1; }

mp=/mnt/root

show_help() {
    echo "Creates Btrfs subvolumes, adjusts fstab, and configures Snapper, grub-btrfs, and Btrfs Assistant."
    echo "Usage: $scriptname {root-dev} {boot-dev} [{efi-dev}]"
    exit 1
}

if [ $# -lt 2 ]; then
    show_help
fi

rootdev="$1"
bootdev="$2"
efidev="$3"

efi=false
[ -n "$efidev" ] && efi=true

preparation() {
    echo "--- Preparing environment ---"
    umount /target/boot/efi 2>/dev/null || true
    umount /target/boot 2>/dev/null || true
    umount /target 2>/dev/null || true
    mkdir -p "$mp"
}

create_subvols() {
    echo "--- Creating Btrfs subvolumes ---"
    mount /dev/"$rootdev" "$mp"
    cd "$mp"

    btrfs subvolume snapshot . @

    find -maxdepth 1 \! -name "@*" \! -name . -exec rm -Rf {} \;

    for subvol in @home @log @cache @tmp @libvirt; do
        btrfs subvolume create $subvol
        mkdir -p $subvol
    done

    [ -d var/log ] && mv var/log/* @log/ 2>/dev/null || true
    [ -d var/cache ] && mv var/cache/* @cache/ 2>/dev/null || true

    cd /
    umount "$mp"
    mount /dev/"$rootdev" -o subvol=@ "$mp"
}

ajusta_fstab() {
    echo "--- Adjusting /etc/fstab ---"
    root_uuid=$(blkid --output export /dev/"$rootdev" | grep ^UUID=)
    fstab_path="$mp/etc/fstab"

    sed -i "/ btrfs /d" "$fstab_path"
    sed -i "/ swap /d" "$fstab_path"

    echo "$root_uuid / btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@ 0 0" >> "$fstab_path"
    echo "$root_uuid /home btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@home 0 0" >> "$fstab_path"
    echo "$root_uuid /var/log btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@log 0 0" >> "$fstab_path"
    echo "$root_uuid /var/cache btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@cache 0 0" >> "$fstab_path"
    echo "$root_uuid /var/lib/libvirt btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@libvirt 0 0" >> "$fstab_path"
    echo "$root_uuid /tmp btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@tmp 0 0" >> "$fstab_path"

    boot_uuid=$(blkid --output export /dev/"$bootdev" | grep ^UUID=)
    echo "$boot_uuid /boot ext4 defaults 0 2" >> "$fstab_path"

    if [ "$efi" = true ]; then
        efi_uuid=$(blkid --output export /dev/"$efidev" | grep ^UUID=)
        echo "$efi_uuid /boot/efi vfat umask=0077 0 1" >> "$fstab_path"
    fi
}

chroot_and_update() {
    echo "--- Entering chroot environment ---"
    for dir in proc sys dev run; do
        mount --bind /$dir "$mp"/$dir
    done
    mount /dev/"$bootdev" "$mp"/boot
    $efi && mount /dev/"$efidev" "$mp"/boot/efi

    chroot "$mp" update-grub
    chroot "$mp" update-initramfs -u
}

configure_snapper_and_tools() {
    echo "--- Configuring Snapper, grub-btrfs and Btrfs Assistant ---"
    chroot "$mp" apt update
    chroot "$mp" apt install -y btrfs-assistant snapper build-essential git
    
    if ! chroot "$mp" command -v grub-btrfsd >/dev/null 2>&1; then
        chroot "$mp" bash -c "cd /tmp && git clone https://github.com/Antynea/grub-btrfs.git && cd grub-btrfs && make install"
    fi
    
    if [ ! -f "$mp/etc/snapper/configs/root" ]; then
        chroot "$mp" snapper -c root create-config /
    fi
    
    chroot "$mp" sed -i \
        -e 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' \
        -e 's/^TIMELINE_MIN_AGE=.*/TIMELINE_MIN_AGE="1800"/' \
        -e 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="10"/' \
        -e 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="10"/' \
        -e 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="0"/' \
        -e 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="3"/' \
        -e 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' \
        /etc/snapper/configs/root

    chroot "$mp" systemctl enable --now snapper-timeline.timer snapper-cleanup.timer grub-btrfsd.service
    chroot "$mp" update-grub

    userhome=$(find "$mp/home" -mindepth 1 -maxdepth 1 -type d | head -n1)
    if [ -n "$userhome" ]; then
        config_file="$userhome/.config/btrfs-assistant/btrfs-assistant.conf"
        mkdir -p "$(dirname "$config_file")"
        if [ ! -f "$config_file" ]; then
            echo -e "[snapper]\nsnapper_boot_enabled=true" > "$config_file"
        else
            if grep -q "^\[snapper\]" "$config_file"; then
                sed -i 's|^snapper_boot_enabled=.*|snapper_boot_enabled=true|' "$config_file"
            else
                echo -e "\n[snapper]\nsnapper_boot_enabled=true" >> "$config_file"
            fi
        fi
        chroot "$mp" chown -R $(basename "$userhome"):$(basename "$userhome") "/home/$(basename "$userhome")/.config"
    fi

    echo "✔️ Snapper, grub-btrfs and Btrfs Assistant successfully configured."
}

unmount_everything() {
    echo "--- Unmounting partitions ---"
    for dir in proc sys dev run; do
        umount "$mp"/$dir 2>/dev/null || true
    done
    $efi && umount "$mp"/boot/efi 2>/dev/null || true
    umount "$mp"/boot 2>/dev/null || true
    umount "$mp" 2>/dev/null || true
}

# Execution
preparation
create_subvols
ajusta_fstab
chroot_and_update
configure_snapper_and_tools
unmount_everything

echo "✅ The script finished successfully!"
