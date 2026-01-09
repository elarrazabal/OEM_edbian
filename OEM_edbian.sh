#!/bin/bash
set -e

# ==================================================
# VARIABLES
# ==================================================
USER_HOME="/home/eduardo"
LIVE_USER="live"
WALLPAPER="$USER_HOME/Descargas/Queen.jpg"
CUSTOM_DEBS="$USER_HOME/edbianpackages"

# ==================================================
# LIMPIEZA
# ==================================================
echo "🧹 Limpiando entorno..."
sudo lb clean --purge || true
rm -rf config .build cache binary chroot
mkdir -p config assets

# ==================================================
# CONFIGURACIÓN LIVE-BUILD (OEM)
# ==================================================
echo "⚙️ Configurando live-build OEM..."
lb config \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --debian-installer live \
  --debian-installer-gui true \
  --archive-areas "main contrib non-free non-free-firmware" \
  --apt-recommends true \
  --image-name "edbian13-xfce-oem"

# ==================================================
# REPOS PARA EL SISTEMA MAESTRO
# ==================================================
mkdir -p config/apt
cat > config/apt/sources.list.chroot << EOF
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

# ==================================================
# PAQUETES DEL SISTEMA (LIVE = INSTALADO)
# ==================================================
mkdir -p config/package-lists

cat > config/package-lists/oem.list.chroot << EOF
# Escritorio
task-xfce-desktop
xfce4-goodies
xfce4-whiskermenu-plugin
plank
picom

# Sistema
lightdm
network-manager
network-manager-applet
sudo
dbus
locales

# Polkit / discos
polkitd
lxpolkit
gvfs
gvfs-backends
udisks2

# Audio / vídeo
pipewire
wireplumber
pulseaudio
vlc

# Apps
chromium
gedit
deja-dup
krita
gimp
ardour
kdenlive
inxi
nala
fastfetch
htop
btop

# Kernel RT
linux-image-rt-amd64

# Firmware
firmware-linux
firmware-linux-nonfree
firmware-iwlwifi
firmware-realtek
firmware-atheros
EOF

# ==================================================
# IDIOMA DEL LIVE
# ==================================================
mkdir -p config/includes.chroot/etc/default
cat > config/includes.chroot/etc/default/locale << EOF
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
EOF

# ==================================================
# AUTOLOGIN LIVE
# ==================================================
mkdir -p config/includes.chroot/etc/lightdm/lightdm.conf.d
cat > config/includes.chroot/etc/lightdm/lightdm.conf.d/01-autologin.conf << EOF
[Seat:*]
autologin-user=${LIVE_USER}
autologin-session=xfce
EOF

# ==================================================
# XFCE OEM (SKEL)
# ==================================================
echo "🎨 Copiando configuración XFCE OEM..."

mkdir -p config/includes.chroot/etc/skel/.config

cp -a "$USER_HOME/.config/xfce4" \
      config/includes.chroot/etc/skel/.config/

[ -d "$USER_HOME/.config/plank" ] && \
  cp -a "$USER_HOME/.config/plank" \
        config/includes.chroot/etc/skel/.config/

[ -f "$USER_HOME/.config/picom.conf" ] && \
  cp "$USER_HOME/.config/picom.conf" \
     config/includes.chroot/etc/skel/.config/

# ==================================================
# FONDO DE PANTALLA OEM
# ==================================================
echo "🖼️ Configurando fondo OEM..."
cp "$WALLPAPER" assets/edbian.jpg

mkdir -p config/includes.chroot/usr/share/backgrounds
mkdir -p config/includes.binary

cp assets/edbian.jpg \
   config/includes.chroot/usr/share/backgrounds/edbian.jpg

cp assets/edbian.jpg \
   config/includes.binary/edbian.jpg

# ==================================================
# PAQUETES .DEB OEM
# ==================================================
echo "📦 Añadiendo paquetes OEM..."

mkdir -p config/includes.chroot/opt/edbian-debs
cp "$CUSTOM_DEBS"/*.deb \
   config/includes.chroot/opt/edbian-debs/ || true

# ==================================================
# HOOK OEM → INSTALA LOS .DEB EN EL SISTEMA MAESTRO
# ==================================================
mkdir -p config/hooks/live

cat > config/hooks/live/99-install-oem-debs.hook.chroot << 'EOF'
#!/bin/sh
set -e

echo "Instalando paquetes OEM..."
dpkg -i /opt/edbian-debs/*.deb || true
apt-get -f install -y
EOF

chmod +x config/hooks/live/99-install-oem-debs.hook.chroot

# ==================================================
# PRESEED OEM (MINIMAL, INTERACTIVO)
# ==================================================
cat > config/includes.binary/preseed.cfg << 'EOF'
### PRIORIDAD NORMAL (PREGUNTA TODO)
d-i debconf/priority string medium

### IDIOMA
d-i debian-installer/locale string es_ES.UTF-8
d-i keyboard-configuration/xkb-keymap select es

### USUARIO
d-i passwd/user-default-groups string audio video sudo plugdev netdev

### NO TASKSEL (SE CLONA EL LIVE)
d-i pkgsel/run boolean false

### POST-INSTALACIÓN (DEBUG)
d-i preseed/late_command string \
  echo "OEM INSTALL OK" > /target/root/oem-installed.txt
EOF

# ==================================================
# GRUB – INSTALADOR OEM NORMAL
# ==================================================
mkdir -p config/includes.binary/boot/grub

cat > config/includes.binary/boot/grub/grub.cfg << EOF
set default=0
set timeout=5

menuentry "Live edbian 13 XFCE OEM" {
  linux /live/vmlinuz boot=live quiet splash
  initrd /live/initrd.img
}

menuentry "Instalar edbian 13 OEM" {
  linux /install.amd/vmlinuz
  initrd /install.amd/initrd.gz
}
EOF

# ==================================================
# BUILD
# ==================================================
echo "🚀 Construyendo ISO OEM..."
sudo lb build

