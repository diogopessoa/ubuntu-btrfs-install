#!/bin/bash
# Author: Diogo Pessoa (https://github.com/diogopessoa)
# License: MIT
# Description: Configure Ubuntu with Btrfs subvolumes and fstab entries.
#              Installation of Snapper and Btrfs Assistant should be done after reboot.

set -e

script=`readlink -f "$0"`
scriptname=`basename "$script"`
[ `id -u` -eq 0 ] || { echo "ERRO: Este script deve ser executado como root."; exit 1; }

mp=/mnt/root

show_help() {
    echo "Cria subvolumes Btrfs e ajusta o fstab."
    echo "Uso: $scriptname {root-dev} {boot-dev} [{efi-dev}]"
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
    echo "--- Preparando ambiente ---"
    umount /target/boot/efi 2>/dev/null || true
    umount /target/boot 2>/dev/null || true
    umount /target 2>/dev/null || true
    mkdir -p "$mp"
}

create_subvols() {
    echo "--- Criando subvolumes Btrfs ---"
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
    echo "--- Ajustando /etc/fstab ---"
    root_uuid=`blkid --output export /dev/"$rootdev" | grep ^UUID=`
    fstab_path="$mp/etc/fstab"

    sed -i "/ btrfs /d" "$fstab_path"
    sed -i "/ swap /d" "$fstab_path"

    echo "$root_uuid / btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@ 0 0" >> "$fstab_path"
    echo "$root_uuid /home btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@home 0 0" >> "$fstab_path"
    echo "$root_uuid /var/log btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@var_log 0 0" >> "$fstab_path"
    echo "$root_uuid /var/cache btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@var_cache 0 0" >> "$fstab_path"
    echo "$root_uuid /var/lib/libvirt btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@libvirt 0 0" >> "$fstab_path"
    echo "$root_uuid /var/lib/flatpak btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@flatpak 0 0" >> "$fstab_path"
    echo "$root_uuid /var/lib/docker btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@docker 0 0" >> "$fstab_path"
    echo "$root_uuid /var/lib/containers btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@containers 0 0" >> "$fstab_path"
   echo "$root_uuid /var/lib/machines btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@machines 0 0" >> "$fstab_path"
   echo "$root_uuid /var/tmp btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@var_tmp 0 0" >> "$fstab_path"
   echo "$root_uuid /tmp btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@tmp 0 0" >> "$fstab_path"
   echo "$root_uuid /opt btrfs defaults,ssd,discard=async,noatime,space_cache=v2,compress=zstd:1,subvol=@opt 0 0" >> "$fstab_path"

    boot_uuid=`blkid --output export /dev/"$bootdev" | grep ^UUID=`
    echo "$boot_uuid /boot ext4 defaults 0 2" >> "$fstab_path"

    if [ "$efi" = true ]; then
        efi_uuid=`blkid --output export /dev/"$efidev" | grep ^UUID=`
        echo "$efi_uuid /boot/efi vfat umask=0077 0 1" >> "$fstab_path"
    fi
}

chroot_and_update() {
    echo "--- Ambiente chroot ---"
    for dir in proc sys dev run; do
        mount --bind /$dir "$mp"/$dir
    done
    mount /dev/"$bootdev" "$mp"/boot
    $efi && mount /dev/"$efidev" "$mp"/boot/efi

    chroot "$mp" update-grub
    chroot "$mp" update-initramfs -u
}

unmount_everything() {
    echo "--- Desmontando partições ---"
    for dir in proc sys dev run; do
        umount "$mp"/$dir 2>/dev/null || true
    done
    $efi && umount "$mp"/boot/efi 2>/dev/null || true
    umount "$mp"/boot 2>/dev/null || true
    umount "$mp" 2>/dev/null || true
}

# Execução
preparation
create_subvols
ajusta_fstab
chroot_and_update
unmount_everything

echo "✅ Script completed successfully!"
echo "🔁 Please reboot the system before installing Snapper and Btrfs Assistant for Snapshots."
