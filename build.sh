#!/bin/bash
# 1. Instalar dependencias y llaves de Devuan
sudo apt-get update
sudo apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools devuan-keyring

# 2. Construir el sistema (Usando el script de 'sid' como puente)
sudo debootstrap --no-check-gpg --variant=minbase --include=linux-image-amd64,lxde-core,network-manager,sudo,fastfetch daedalus ./chroot http://deb.devuan.org/merged /usr/share/debootstrap/scripts/sid

# 3. Inyectar wallpaper
sudo mkdir -p ./chroot/usr/share/images/desktop-base/
sudo cp wallpaperITCMOS.jpg ./chroot/usr/share/images/desktop-base/

# 4. Empaquetar
mkdir -p image/live
sudo mksquashfs chroot image/live/filesystem.squashfs -comp xz -e boot

# 5. Copiar Kernel (Asegurando la ruta)
sudo cp ./chroot/boot/vmlinuz* image/live/vmlinuz
sudo cp ./chroot/boot/initrd* image/live/initrd

# 6. Crear ISO
grub-mkrescue -o ITCM_OS_v1.iso image
