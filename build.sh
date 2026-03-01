#!/bin/bash
set -e

# Nombre fijo del ISO (importante para que coincida con el upload-artifact en GitHub Actions)
ISO_NAME="ITCM_OS_latest.iso"

echo "=== Construyendo ITCM_OS - Versión con autologin corregido ==="
echo "ISO final se generará como: $ISO_NAME"

echo "=== Instalando herramientas necesarias en el host ==="
sudo apt-get update -qq
sudo apt-get install -y -qq debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools wget ca-certificates

echo "=== PASO 1: Construyendo sistema base mínima (Devuan daedalus) ==="
sudo rm -rf ./chroot
sudo debootstrap --no-check-gpg --variant=minbase \
    --include=linux-image-amd64,sysvinit-core,sudo,locales,tzdata \
    daedalus ./chroot http://deb.devuan.org/merged

echo "=== Montando sistemas de archivos virtuales ==="
sudo chroot ./chroot mount -t proc none /proc
sudo chroot ./chroot mount -t sysfs none /sys
sudo chroot ./chroot mount -t devtmpfs none /dev

echo "=== PASO 2: Instalando entorno gráfico, live-boot y herramientas ==="
sudo chroot ./chroot apt-get update -qq
sudo chroot ./chroot apt-get install -y --no-install-recommends \
    xserver-xorg lxde lightdm lightdm-gtk-greeter \
    network-manager neofetch console-setup \
    live-boot live-config live-config-sysvinit \
    git calamares calamares-settings-debian \
    plank mousepad galculator htop gparted qpdfview extrepo

echo "=== Instalando LibreWolf (navegador recomendado) ==="
sudo chroot ./chroot extrepo enable librewolf
sudo chroot ./chroot apt-get update -qq
sudo chroot ./chroot apt-get install -y librewolf

echo "=== Configuración de locales y zona horaria ==="
echo "es_MX.UTF-8 UTF-8" | sudo tee ./chroot/etc/locale.gen
sudo chroot ./chroot locale-gen
echo "LANG=es_MX.UTF-8" | sudo tee ./chroot/etc/locale.conf
echo "America/Monterrey" | sudo tee ./chroot/etc/timezone
DEBIAN_FRONTEND=noninteractive sudo chroot ./chroot dpkg-reconfigure --frontend noninteractive tzdata

echo "=== Personalización del sistema (skeleton, tema, fondo, etc.) ==="

# 1. Copiar wallpaper global
sudo mkdir -p ./chroot/usr/share/backgrounds/
sudo cp wallpaperITCMOS.jpg ./chroot/usr/share/backgrounds/itcm-wallpaper.jpg || echo "Advertencia: wallpaperITCMOS.jpg no encontrado"

# 2. Instalar tema Atmospheric
sudo chroot ./chroot git -c http.sslVerify=false clone https://github.com/Suazo-kun/LocOS-Atmospheric-Theme /tmp/LocOS-Atmospheric-Theme
sudo chroot ./chroot bash -c "cd /tmp/LocOS-Atmospheric-Theme && sed -i 's/sudo //g' install.sh && chmod +x install.sh && ./install.sh"
sudo rm -rf ./chroot/tmp/LocOS-Atmospheric-Theme

# 3. Crear estructura skeleton para el usuario live
sudo mkdir -p ./chroot/etc/skel/.config/{pcmanfm/LXDE,lxsession/LXDE,openbox,lxpanel/LXDE/panels,autostart} \
              ./chroot/etc/skel/Desktop

# Wallpaper en escritorio
cat << 'EOF' | sudo tee ./chroot/etc/skel/.config/pcmanfm/LXDE/desktop.conf
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

# Tema y sesión
cat << 'EOF' | sudo tee ./chroot/etc/skel/.config/lxsession/LXDE/desktop.conf
[Session]
window_manager=openbox-lxde
[GTK]
sNet/ThemeName=Atmospheric-Theme
EOF

sudo cp ./chroot/etc/xdg/openbox/LXDE-rc.xml ./chroot/etc/skel/.config/openbox/lxde-rc.xml 2>/dev/null || true
sudo sed -i 's/<name>.*<\/name>/<name>Atmospheric-Theme<\/name>/' ./chroot/etc/skel/.config/openbox/lxde-rc.xml 2>/dev/null || true

# Mover panel LXDE a la parte superior
sudo cp ./chroot/usr/share/lxpanel/profile/LXDE/panels/panel ./chroot/etc/skel/.config/lxpanel/LXDE/panels/panel 2>/dev/null || true
sudo sed -i 's/edge=bottom/edge=top/g' ./chroot/etc/skel/.config/lxpanel/LXDE/panels/panel 2>/dev/null || true

# Autostart Plank
cat << 'EOF' | sudo tee ./chroot/etc/skel/.config/autostart/plank.desktop
[Desktop Entry]
Type=Application
Exec=plank
Name=Plank
EOF

# Acceso directo a Calamares en el escritorio
cat << 'EOF' | sudo tee ./chroot/etc/skel/Desktop/Instalar_ITCM_OS.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Instalar ITCM_OS
Exec=sudo calamares
Icon=drive-harddisk
Terminal=false
StartupNotify=true
EOF
sudo chmod +x ./chroot/etc/skel/Desktop/Instalar_ITCM_OS.desktop

# Neofetch al abrir terminal
sudo bash -c 'echo "neofetch" >> ./chroot/etc/skel/.bashrc'

# =============================================
# CONFIGURACIÓN CRUCIAL: AUTOLOGIN EN LIGHTDM
# =============================================
echo "=== Configurando autologin directo como usuario 'alumno' ==="
sudo mkdir -p ./chroot/etc/lightdm/lightdm.conf.d

cat << 'EOF' | sudo tee ./chroot/etc/lightdm/lightdm.conf.d/99-live-autologin.conf
[Seat:*]
autologin-user=alumno
autologin-user-timeout=0
greeter-hide-users=true
allow-guest=false
greeter-show-manual-login=false
user-session=LXDE
EOF

echo "=== Limpiando cachés y desmontando ==="
sudo chroot ./chroot umount /proc /sys /dev || true
sudo chroot ./chroot apt-get clean
sudo chroot ./chroot apt-get autoclean

echo "=== Empaquetando el sistema en squashfs ==="
mkdir -p image/live
sudo rm -f image/live/filesystem.squashfs
sudo mksquashfs chroot image/live/filesystem.squashfs -comp xz -e boot

echo "=== Copiando kernel e initrd ==="
sudo cp chroot/boot/vmlinuz-* image/live/vmlinuz
sudo cp chroot/boot/initrd.img-* image/live/initrd

echo "=== Creando configuración de GRUB para live boot ==="
mkdir -p image/boot/grub
cat << 'EOF' | sudo tee image/boot/grub/grub.cfg
set default=0
set timeout=3

menuentry "ITCM_OS - Instituto Tecnológico de Ciudad Madero (Live)" {
    linux /live/vmlinuz boot=live components quiet splash \
        live-config.username=alumno \
        live-config.user-fullname="Alumno ITCM" \
        live-config.user-default-groups="audio cdrom dip floppy video plugdev netdev scanner bluetooth sudo" \
        live-config.hostname=itcm-os-live \
        live-config.locales=es_MX.UTF-8 \
        live-config.keyboard-layouts=latam
    initrd /live/initrd
}
EOF

echo "=== Generando ISO final ==="
rm -f "$ISO_NAME"
grub-mkrescue -o "$ISO_NAME" image

echo ""
echo "¡Construcción finalizada!"
echo "Archivo generado: $ISO_NAME"
echo "Tamaño aproximado:"
ls -lh "$ISO_NAME"
echo ""
echo "Puedes grabar este archivo en USB con:"
echo "• Ventoy (recomendado)"
echo "• Rufus (modo DD Image)"
echo "• balenaEtcher"
echo ""
