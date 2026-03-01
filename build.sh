#!/bin/bash
set -e
echo "=== Instalando herramientas ==="
sudo apt-get update -qq
sudo apt-get install -y -qq debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools wget ca-certificates

echo "=== PASO 1: Construyendo base mínima ==="
sudo debootstrap --no-check-gpg --variant=minbase --include=linux-image-amd64,sysvinit-core,sudo,locales,tzdata daedalus ./chroot http://deb.devuan.org/merged /usr/share/debootstrap/scripts/sid

echo "=== Montando sistemas ==="
sudo chroot ./chroot mount -t proc none /proc
sudo chroot ./chroot mount -t sysfs none /sys
sudo chroot ./chroot mount -t devtmpfs none /dev

echo "=== PASO 2: Instalando Entorno y LIVE BOOT ==="
sudo chroot ./chroot apt-get update
# ¡AQUÍ ESTÁ LA MAGIA! Agregamos live-boot y live-config
sudo chroot ./chroot apt-get install -y --no-install-recommends lxde-core lightdm network-manager neofetch console-setup live-boot live-config

echo "=== Locales ==="
echo "es_MX.UTF-8 UTF-8" | sudo tee ./chroot/etc/locale.gen
sudo chroot ./chroot locale-gen
echo "LANG=es_MX.UTF-8" | sudo tee ./chroot/etc/locale.conf
echo "America/Monterrey" | sudo tee ./chroot/etc/timezone
DEBIAN_FRONTEND=noninteractive sudo chroot ./chroot dpkg-reconfigure tzdata

echo "=== Wallpaper ==="
sudo mkdir -p ./chroot/usr/share/backgrounds/
sudo cp wallpaperITCMOS.jpg ./chroot/usr/share/backgrounds/itcm-wallpaper.jpg

echo "=== Limpiando ==="
sudo chroot ./chroot umount /proc /sys /dev
sudo chroot ./chroot apt-get clean

echo "=== Empaquetando squashfs ==="
mkdir -p image/live
sudo mksquashfs chroot image/live/filesystem.squashfs -comp xz -e boot

echo "=== Kernel e Initrd ==="
sudo cp chroot/boot/vmlinuz-* image/live/vmlinuz
sudo cp chroot/boot/initrd.img-* image/live/initrd

echo "=== Creando Menu GRUB (El Mapa) ==="
mkdir -p image/boot/grub
cat << 'EOF' | sudo tee image/boot/grub/grub.cfg
set default=0
set timeout=5
menuentry "ITCM_OS - Instituto Tecnologico de Ciudad Madero" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd
}
EOF

echo "=== Generando ISO ==="
grub-mkrescue -o ITCM_OS_v1.iso image
