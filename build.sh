#!/bin/bash
# 1. Instalar herramientas de sistema
sudo apt-get update
sudo apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools

# 2. Descargar el script de debootstrap manualmente (Truco Maestro)
sudo mkdir -p /usr/share/debootstrap/scripts
sudo wget https://raw.githubusercontent.com/devuan-packages/debootstrap/master/scripts/daedalus -O /usr/share/debootstrap/scripts/daedalus
sudo chmod 644 /usr/share/debootstrap/scripts/daedalus

# 3. Construir la distro (Forzando la descarga real)
sudo debootstrap --no-check-gpg --variant=minbase --include=linux-image-amd64,lxde-core,network-manager,sudo,fastfetch daedalus ./chroot http://deb.devuan.org/merged

# 4. Inyectar wallpaper
sudo mkdir -p ./chroot/usr/share/images/desktop-base/
sudo cp wallpaperITCMOS.jpg ./chroot/usr/share/images/desktop-base/

# 5. Empaquetar el sistema real
mkdir -p image/live
sudo mksquashfs chroot image/live/filesystem.squashfs -comp xz

# 6. Copiar Kernel y preparar ISO
sudo cp chroot/boot/vmlinuz* image/live/vmlinuz
sudo cp chroot/boot/initrd* image/live/initrd
grub-mkrescue -o ITCM_OS_v1.iso image
