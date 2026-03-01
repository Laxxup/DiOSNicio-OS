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
# Metemos todo tu kit ligero, Plank, Calamares y Extrepo
sudo chroot ./chroot apt-get install -y --no-install-recommends xserver-xorg lxde lightdm lightdm-gtk-greeter network-manager neofetch console-setup live-boot live-config live-config-sysvinit git calamares calamares-settings-debian plank mousepad galculator htop gparted qpdfview extrepo

echo "=== Instalando LibreWolf ==="
sudo chroot ./chroot extrepo enable librewolf
sudo chroot ./chroot apt-get update
sudo chroot ./chroot apt-get install -y librewolf

echo "=== Configurando Usuario Temporal 'alumno' ==="
sudo chroot ./chroot groupadd -r autologin || true
sudo chroot ./chroot useradd -m -c "Alumno ITCM" -G sudo,video,audio,netdev,plugdev,autologin -s /bin/bash alumno
echo "alumno:alumno" | sudo chroot ./chroot chpasswd
echo "root:root" | sudo chroot ./chroot chpasswd

# Autologin seguro
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

echo "=== Customizando LXDE (El toque Maestro) ==="
sudo mkdir -p ./chroot/usr/share/backgrounds/
sudo cp wallpaperITCMOS.jpg ./chroot/usr/share/backgrounds/itcm-wallpaper.jpg

# Instalamos el Tema Atmospheric en el sistema base
sudo chroot ./chroot git -c http.sslVerify=false clone https://github.com/Suazo-kun/LocOS-Atmospheric-Theme /tmp/LocOS-Atmospheric-Theme
sudo chroot ./chroot bash -c "cd /tmp/LocOS-Atmospheric-Theme && sed -i 's/sudo //g' install.sh && chmod +x install.sh && ./install.sh"
sudo rm -rf ./chroot/tmp/LocOS-Atmospheric-Theme

# INYECCIÓN DIRECTA AL USUARIO ALUMNO
sudo mkdir -p ./chroot/home/alumno/.config/pcmanfm/LXDE/
cat << 'EOF' | sudo tee ./chroot/home/alumno/.config/pcmanfm/LXDE/desktop.conf
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

sudo mkdir -p ./chroot/home/alumno/.config/lxsession/LXDE/
cat << 'EOF' | sudo tee ./chroot/home/alumno/.config/lxsession/LXDE/desktop.conf
[Session]
window_manager=openbox-lxde
[GTK]
sNet/ThemeName=Atmospheric-Theme
EOF

sudo mkdir -p ./chroot/home/alumno/.config/lxpanel/LXDE/panels/
sudo cp ./chroot/usr/share/lxpanel/profile/LXDE/panels/panel ./chroot/home/alumno/.config/lxpanel/LXDE/panels/panel || true
sudo sed -i 's/edge=bottom/edge=top/g' ./chroot/home/alumno/.config/lxpanel/LXDE/panels/panel || true

sudo mkdir -p ./chroot/home/alumno/.config/openbox/
sudo cp ./chroot/etc/xdg/openbox/LXDE-rc.xml ./chroot/home/alumno/.config/openbox/lxde-rc.xml || true
sudo sed -i 's/<name>.*<\/name>/<name>Atmospheric-Theme<\/name>/' ./chroot/home/alumno/.config/openbox/lxde-rc.xml || true

sudo mkdir -p ./chroot/home/alumno/.config/autostart/
cat << 'EOF' | sudo tee ./chroot/home/alumno/.config/autostart/plank.desktop
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Plank
EOF

echo "=== Icono de Instalador ==="
sudo mkdir -p ./chroot/home/alumno/Desktop
cat << 'EOF' | sudo tee ./chroot/home/alumno/Desktop/Instalar_ITCM_OS.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Instalar ITCM_OS
Comment=Instalar el sistema de Madero en el disco duro
Exec=sudo calamares
Icon=drive-harddisk
Terminal=false
StartupNotify=true
EOF
sudo chmod +x ./chroot/home/alumno/Desktop/Instalar_ITCM_OS.desktop

echo "=== Terminal Hacker ==="
sudo bash -c 'echo "neofetch" >> ./chroot/home/alumno/.bashrc'

# Arreglamos los permisos para que 'alumno' sea dueño de todo esto
sudo chroot ./chroot chown -R alumno:alumno /home/alumno

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
menuentry "ITCM_OS Live - Tec de Madero" {
    linux /live/vmlinuz boot=live components quiet splash
    initrd /live/initrd
}
EOF

echo "=== Generando ISO ==="
grub-mkrescue -o ITCM_OS_v1.iso image
