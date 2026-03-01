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
# ¡Agregamos 'git' aquí para poder clonar el tema!
sudo chroot ./chroot apt-get install -y --no-install-recommends xserver-xorg lxde lightdm lightdm-gtk-greeter network-manager neofetch console-setup live-boot live-config live-config-sysvinit git

echo "=== Configurando Usuario y Autologin ==="
sudo chroot ./chroot groupadd -r autologin || true
sudo chroot ./chroot useradd -m -c "Alumno ITCM" -G sudo,video,audio,netdev,plugdev,autologin -s /bin/bash alumno
echo "alumno:alumno" | sudo chroot ./chroot chpasswd
echo "root:root" | sudo chroot ./chroot chpasswd

sudo mkdir -p ./chroot/etc/lightdm/lightdm.conf.d/
cat << 'EOF' | sudo tee ./chroot/etc/lightdm/lightdm.conf.d/01_autologin.conf
[Seat:*]
autologin-guest=false
autologin-user=alumno
autologin-user-timeout=0
user-session=LXDE
EOF

echo "=== Locales ==="
echo "es_MX.UTF-8 UTF-8" | sudo tee ./chroot/etc/locale.gen
sudo chroot ./chroot locale-gen
echo "LANG=es_MX.UTF-8" | sudo tee ./chroot/etc/locale.conf
echo "America/Monterrey" | sudo tee ./chroot/etc/timezone
DEBIAN_FRONTEND=noninteractive sudo chroot ./chroot dpkg-reconfigure tzdata

echo "=== Customizando LXDE (Wallpaper y Tema) ==="
# 1. Inyectando el Wallpaper del ITCM
sudo mkdir -p ./chroot/usr/share/backgrounds/
sudo cp wallpaperITCMOS.jpg ./chroot/usr/share/backgrounds/itcm-wallpaper.jpg

sudo mkdir -p ./chroot/etc/xdg/pcmanfm/LXDE/
cat << 'EOF' | sudo tee ./chroot/etc/xdg/pcmanfm/LXDE/pcmanfm.conf
[desktop]
wallpaper_mode=crop
wallpaper_common=1
wallpaper=/usr/share/backgrounds/itcm-wallpaper.jpg
bgcolor=#000000
fgcolor=#ffffff
show_wm_menu=0
sort=mtime;ascending;
show_documents=0
show_trash=1
show_mounts=1
EOF

# 2. Instalando el LocOS-Atmospheric-Theme
echo "Clonando e instalando el tema..."
sudo chroot ./chroot git -c http.sslVerify=false clone https://github.com/Suazo-kun/LocOS-Atmospheric-Theme /tmp/LocOS-Atmospheric-Theme
# Le quitamos los "sudo" al script original para que no trabe la compilación automatizada
sudo chroot ./chroot bash -c "cd /tmp/LocOS-Atmospheric-Theme && sed -i 's/sudo //g' install.sh && chmod +x install.sh && ./install.sh"
sudo rm -rf ./chroot/tmp/LocOS-Atmospheric-Theme

# 3. Aplicando el tema globalmente para que el alumno lo vea al arrancar
sudo chroot ./chroot bash -c "sed -i 's/sNet\/ThemeName=.*/sNet\/ThemeName=Atmospheric-Theme/g' /etc/xdg/lxsession/LXDE/desktop.conf || true"
sudo chroot ./chroot bash -c "sed -i '/<theme>/,/<\/theme>/ s/<name>[^<]*<\/name>/<name>Atmospheric-Theme<\/name>/' /etc/xdg/openbox/LXDE-rc.xml || true"

echo "=== Limpiando ==="
sudo chroot ./chroot umount /proc /sys /dev
sudo chroot ./chroot apt-get clean

echo "=== Empaquetando squashfs ==="
mkdir -p image/live
sudo mksquashfs chroot image/live/filesystem.squashfs -comp xz -e boot

echo "=== Kernel e Initrd ==="
sudo cp chroot/boot/vmlinuz-* image/live/vmlinuz
sudo cp chroot/boot/initrd.img-* image/live/initrd

echo "=== Creando Menu GRUB ==="
mkdir -p image/boot/grub
cat << 'EOF' | sudo tee image/boot/grub/grub.cfg
set default=0
set timeout=5
menuentry "ITCM_OS Live - Instituto Tecnologico de Ciudad Madero" {
    linux /live/vmlinuz boot=live components quiet splash
    initrd /live/initrd
}
EOF

echo "=== Generando ISO ==="
grub-mkrescue -o ITCM_OS_v1.iso image
