#!/bin/bash
set -e

echo "🧹 Limpieza"
sudo lb clean --purge || true
sudo rm -rf config .build cache binary chroot
mkdir -p config

echo "⚙️ Configuración base"
lb config \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --bootappend-live "boot=live components quiet splash threadirqs preempt=full locales=es_ES.UTF-8 keyboard-layouts=es" \
  --archive-areas "main contrib non-free non-free-firmware" \
  --apt-recommends true \
  --image-name "edbian13-xfce"

# ==================================================
# 🌍 LOCALE
# ==================================================
echo "🌍 Locale ES"
for T in chroot installer; do
  mkdir -p config/includes.$T/etc/default
  cat > config/includes.$T/etc/default/locale << EOF
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
EOF
done

# ==================================================
# 🌐 REPOS
# ==================================================
echo "🌐 Repositorios"
mkdir -p config/apt config/includes.installer/etc/apt
cat > config/apt/sources.list.chroot << EOF
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
cp config/apt/sources.list.chroot config/includes.installer/etc/apt/sources.list

# ==================================================
# 📦 PAQUETES (LIVE + INSTALADO)
# ==================================================
echo "📦 Paquetes"
mkdir -p config/package-lists
cat > config/package-lists/desktop.list.chroot << EOF
task-xfce-desktop
xfce4-session
xfce4-terminal
lightdm
network-manager
network-manager-gnome
sudo
plank
picom
pipewire
pipewire-pulse
pipewire-jack
wireplumber
linux-image-rt-amd64
nala
htop
btop
fastfetch
calamares
calamares-settings-debian
python3-yaml
python3-pyqt5
rsync
chromium
libgtk-3-0
libnss3
libxss1
libasound2
xfce4-goodies
thunar
thunar-volman
thunar-archive-plugin
inxi
wget
git
curl
grep
plasma-discover

# --- RED (OBLIGATORIO PARA LIVE) ---
network-manager
network-manager-gnome
ifupdown
wpasupplicant

# --- FIRMWARE (RECOMENDADO) ---
firmware-linux
firmware-linux-nonfree
firmware-misc-nonfree

EOF

# ==================================================
# 🎨 XFCE – CONFIGURACIÓN REAL (LIVE + CALAMARES)
# ==================================================
echo "🎨 [XFCE] Aplicando configuración real al usuario live"


echo "🎨 [XFCE] Configuración OEM REAL"

OEM_SKEL="config/includes.chroot/etc/skel/.config"
BACKGROUND_DIR="config/includes.chroot/usr/share/backgrounds"
BACKGROUND_NAME="Queen.jpg"   #Este fichero se debe encontrar en "/usr/share/backgrounds/xfce"
HOME="/home/eduardo"
mkdir -p "$OEM_SKEL"

cp -a "$HOME/.config/xfce4" "$OEM_SKEL/"
#cp -a "$HOME/.config/plank" "$OEM_SKEL/"
if [[ -f "$HOME/.config/picom.conf" && -d "$OEM_SKEL" ]]; then
    cp -a "$HOME/.config/picom.conf" "$OEM_SKEL/"
fi


echo "🖼️ [WALLPAPER] Instalando fondo de pantalla"

mkdir -p "$BACKGROUND_DIR"
cp "/usr/share/backgrounds/xfce/$BACKGROUND_NAME" "$BACKGROUND_DIR/"

mkdir -p "$OEM_SKEL/xfce4/xfconf/xfce-perchannel-xml"

cat > "$OEM_SKEL/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop">
    <property name="screen0">
      <property name="monitor0">
        <property name="workspace0">
          <property name="image-path" type="string"
                    value="/usr/share/backgrounds/xfce/${BACKGROUND_NAME}"/>
          <property name="image-style" type="int" value="5"/>
          <property name="color-style" type="int" value="0"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

# ==================================================
# 🚀 AUTOSTART GLOBAL
# ==================================================
echo "🚀 [AUTOSTART] Plank y Picom"

mkdir -p config/includes.chroot/etc/xdg/autostart

cat > config/includes.chroot/etc/xdg/autostart/plank.desktop << EOF
[Desktop Entry]
Type=Application
Name=Plank
Exec=plank
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
EOF

cat > config/includes.chroot/etc/xdg/autostart/picom.desktop << EOF
[Desktop Entry]
Type=Application
Name=Picom
Exec=picom --config /etc/xdg/picom/picom.conf
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
EOF




# ==================================================
# ⚓ PLANK – ICONOS OEM (desde sistema raíz)
# ==================================================
echo "⚓ [PLANK] Copiando iconos (launchers) OEM"

PLANK_LAUNCHERS_SRC="$HOME/.config/plank/dock1/launchers"
PLANK_LAUNCHERS_DST="config/includes.chroot/etc/skel/.config/plank/dock1/launchers"

mkdir -p "$PLANK_LAUNCHERS_DST"

if [ -d "$PLANK_LAUNCHERS_SRC" ]; then
  cp -a "$PLANK_LAUNCHERS_SRC/." "$PLANK_LAUNCHERS_DST/"
else
  echo "⚠️ No se encontraron launchers de Plank"
fi

PLANK_SKEL_DIR="config/includes.chroot/etc/skel/.config/plank/dock1"

cat > "$PLANK_SKEL_DIR/settings" << 'EOF'
[PlankDockPreferences]
Alignment=center
AutoHide=true
AutoHideDelay=200
AutoHideDelayShow=150
IconSize=36
ZoomEnabled=true
ZoomPercent=150
PressureReveal=true
Theme=Transparent
HideMode=always
EOF



# ==================================================
# FONDO DE PANTALLA)
# ==================================================
cat > config/hooks/normal/50-xfce-wallpaper.hook.chroot << 'EOF'
#!/bin/sh
set -e

xfconf-query -c xfce4-desktop \
  -p /backdrop/screen0/monitor0/workspace0/image-path \
  -s /usr/share/backgrounds/xfce/Queen.jpg || true

xfconf-query -c xfce4-desktop \
  -p /backdrop/screen0/monitor0/workspace0/image-style \
  -s 5 || true
EOF

chmod +x config/hooks/normal/50-xfce-wallpaper.hook.chroot



# ==================================================
# 🔄 GLIB – COMPILAR SCHEMAS (PLANK)
# ==================================================
echo "🔄 [GLIB] Compilando esquemas GSettings"

mkdir -p config/hooks/normal

# ==================================================
# HOOK PARA ACTIVAR RED)
# ==================================================

cat > config/hooks/normal/10-networkmanager.hook.chroot << 'EOF'
#!/bin/sh
set -e

echo "🌐 [NET] Activando NetworkManager"

# Asegurar que está habilitado
systemctl unmask NetworkManager.service || true
systemctl enable NetworkManager.service || true
systemctl enable NetworkManager-wait-online.service || true
EOF

chmod +x config/hooks/normal/10-networkmanager.hook.chroot

# ==================================================
# EVITAR CONFLICTOS RED LEGACY
# ==================================================
cat > config/hooks/normal/11-disable-legacy-networking.hook.chroot << 'EOF'
#!/bin/sh
set -e

echo "🌐 [NET] Desactivando networking legacy"

systemctl disable networking.service || true
systemctl mask networking.service || true
EOF

chmod +x config/hooks/normal/11-disable-legacy-networking.hook.chroot

# ==================================================
# GARANTIZAR DHCP
# ==================================================
cat > config/hooks/normal/12-dhcp-fallback.hook.chroot << 'EOF'
#!/bin/sh
set -e

echo "🌐 [NET] Asegurando DHCP por defecto"

mkdir -p /etc/NetworkManager/conf.d

cat > /etc/NetworkManager/conf.d/10-dhcp.conf << EOL
[main]
dhcp=internal
EOL
EOF

chmod +x config/hooks/normal/12-dhcp-fallback.hook.chroot


cat > config/hooks/normal/40-compile-gschemas.hook.chroot << 'EOF'
#!/bin/sh
set -e

if command -v glib-compile-schemas >/dev/null 2>&1; then
  glib-compile-schemas /usr/share/glib-2.0/schemas
fi
EOF

chmod +x config/hooks/normal/40-compile-gschemas.hook.chroot



# ==================================================
# 🧠 DCONF – PERFIL SISTEMA
# ==================================================
echo "🧠 [DCONF] Perfil sistema"

mkdir -p config/includes.chroot/etc/dconf/profile

cat > config/includes.chroot/etc/dconf/profile/user << EOF
user-db:user
system-db:local
EOF


# ==================================================
# 🔄 DCONF – UPDATE
# ==================================================
echo "🔄 [DCONF] Update"

mkdir -p config/hooks/normal

cat > config/hooks/normal/30-dconf-update.hook.chroot << 'EOF'
#!/bin/sh
set -e
if command -v dconf >/dev/null 2>&1; then
  dconf update
fi
EOF

chmod +x config/hooks/normal/30-dconf-update.hook.chroot


# ==================================================
# 🔐 SUDO (GARANTIZADO)
# ==================================================
echo "🔐 Sudoers"
for T in chroot installer; do
  mkdir -p config/includes.$T/etc/sudoers.d
  echo "%sudo ALL=(ALL) ALL" > config/includes.$T/etc/sudoers.d/90-sudo
  chmod 440 config/includes.$T/etc/sudoers.d/90-sudo
done



# ==================================================
# 📦 DEBS PERSONALIZADOS – AUTO (LIVE + CALAMARES)
# ==================================================
echo "📦 [DEBS] Preparando instalación automática de .deb personalizados"

# Directorio origen (host)
SRC_DEBS="$HOME/Edbian_Project/edbianpackages"

# Directorio destino dentro del sistema Live / instalado
LOCAL_REPO="config/includes.chroot/usr/local/share/edbian-repo"

# Crear repo local
mkdir -p "$LOCAL_REPO"

# Copiar todos los .deb disponibles
cp "$SRC_DEBS"/*.deb "$LOCAL_REPO/"

# Hook para indexar e instalar TODOS los paquetes del repo
HOOK="config/hooks/normal/70-edbian-local-debs.hook.chroot"

cat > "$HOOK" << 'EOF'
#!/bin/sh
set -e

REPO_DIR="/usr/local/share/edbian-repo"

echo "📦 [DEBS] Instalando herramientas necesarias"
apt update
apt install -y dpkg-dev

echo "📦 [DEBS] Generando índice del repo local"
cd "$REPO_DIR"
dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

echo "📦 [DEBS] Registrando repo local en APT"
echo "deb [trusted=yes] file:$REPO_DIR ./" \
  > /etc/apt/sources.list.d/edbian-local.list

echo "📦 [DEBS] Actualizando APT"
apt update

echo "📦 [DEBS] Instalando TODOS los paquetes del repo local"
PKGS="$(zcat Packages.gz | awk '/^Package: / {print $2}')"

if [ -n "$PKGS" ]; then
    apt install -y $PKGS
else
    echo "⚠️ [DEBS] No se encontraron paquetes para instalar"
fi
EOF


# Hacer ejecutable el hook
chmod +x "$HOOK"




# ==================================================
# ⚙️ KERNEL RT – parámetros y prioridad
# ==================================================
echo "⚙️ [RT] Configuración kernel RT"

for T in chroot installer; do
  mkdir -p config/includes.$T/etc/default
  cat >> config/includes.$T/etc/default/grub << EOF
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash threadirqs preempt=full"
EOF
done


# ==================================================
# 🎛️ LIMITES RT – audio profesional
# ==================================================
echo "🎛️ [RT] Límites PAM audio"

for T in chroot installer; do
  mkdir -p config/includes.$T/etc/security/limits.d
  cat > config/includes.$T/etc/security/limits.d/99-audio-rt.conf << EOF
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice      -19
EOF
done


# ==================================================
# 🧠 SYSCTL – baja latencia
# ==================================================
echo "🧠 [RT] Sysctl baja latencia"

for T in chroot installer; do
  mkdir -p config/includes.$T/etc/sysctl.d
  cat > config/includes.$T/etc/sysctl.d/99-rt-audio.conf << EOF
vm.swappiness=10
kernel.sched_rt_runtime_us = -1
fs.inotify.max_user_watches = 524288
EOF
done

# ==================================================
# 🔊 PIPEWIRE – configuración RT
# ==================================================
echo "🔊 [AUDIO] PipeWire RT"

for T in chroot installer; do
  mkdir -p config/includes.$T/etc/pipewire/pipewire.conf.d
  cat > config/includes.$T/etc/pipewire/pipewire.conf.d/99-rt.conf << EOF
context.properties = {
    default.clock.rate          = 48000
    default.clock.quantum       = 128
    default.clock.min-quantum   = 32
    default.clock.max-quantum   = 256
}
EOF
done


# ==================================================
# 🔊 WIREPLUMBER – permitir RT
# ==================================================
echo "🔊 [AUDIO] WirePlumber RT"

for T in chroot installer; do
  mkdir -p config/includes.$T/etc/wireplumber/wireplumber.conf.d
  cat > config/includes.$T/etc/wireplumber/wireplumber.conf.d/99-rt.conf << EOF
monitor.alsa.rules = [
  {
    matches = [{ node.name = "~alsa_output.*" }]
    actions = {
      update-props = {
        node.latency = "128/48000"
        priority.session = 100
        priority.driver = 100
      }
    }
  }
]
EOF
done


# ==================================================
# 🔊 PIPEWIRE – activación correcta
# ==================================================
echo "🔊 [AUDIO] Activando PipeWire"

mkdir -p config/hooks/normal
cat > config/hooks/normal/80-enable-pipewire.hook.chroot << 'EOF'
#!/bin/sh
set -e

systemctl --global disable pulseaudio.service pulseaudio.socket || true
systemctl --global enable pipewire.socket
systemctl --global enable pipewire-pulse.socket
systemctl --global enable wireplumber.service
EOF

chmod +x config/hooks/normal/80-enable-pipewire.hook.chroot



# ==================================================
# 🧠 DCONF – perfil del sistema
# ==================================================
echo "🧠 [DCONF] Perfil sistema"

for T in chroot installer; do
  mkdir -p config/includes.$T/etc/dconf/profile
  cat > config/includes.$T/etc/dconf/profile/user << EOF
user-db:user
system-db:local
EOF
done


# ==================================================
# 🔄 DCONF – actualizar base
# ==================================================
echo "🔄 [DCONF] Actualizando base"

mkdir -p config/hooks/normal
cat > config/hooks/normal/30-dconf-update.hook.chroot << 'EOF'
#!/bin/sh
set -e

if command -v dconf >/dev/null 2>&1; then
  dconf update || true
fi
EOF

chmod +x config/hooks/normal/30-dconf-update.hook.chroot


# ===============================
# 👤 [USER] Añadir usuario a grupos audio / sudo / etc
# ===============================
echo "👤 [USER] Configurando grupos del usuario (audio, sudo, video...)"

mkdir -p config/hooks/normal

cat > config/hooks/normal/60-user-groups.hook.chroot << 'EOF'
#!/bin/sh
set -e

echo "👤 Detectando usuario real..."

# Obtener usuario humano (UID >= 1000)
USER_NAME=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}' /etc/passwd)

if [ -z "$USER_NAME" ]; then
    echo "⚠️ No se encontró usuario humano, saliendo"
    exit 0
fi

echo "👤 Usuario detectado: $USER_NAME"

for grp in audio video sudo plugdev netdev; do
    if getent group "$grp" >/dev/null; then
        usermod -aG "$grp" "$USER_NAME"
        echo "✅ Añadido a grupo: $grp"
    else
        echo "⚠️ Grupo no existe: $grp"
    fi
done
EOF

chmod +x config/hooks/normal/60-user-groups.hook.chroot




# ==================================================
# 🧹 LIMPIEZA FINAL – eliminar repo local APT
# ==================================================
echo "🧹 [APT] Limpieza de repositorio local Edbian"

CLEAN_HOOK="config/hooks/normal/90-cleanup-local-repo.hook.chroot"

cat > "$CLEAN_HOOK" << 'EOF'
#!/bin/sh
set -e

echo "🧹 [APT] Eliminando repositorio local Edbian..."

# Eliminar sources.list.d del repo local
rm -f /etc/apt/sources.list.d/edbian-local.list

# Eliminar posibles restos file:
sed -i '/file:\/usr\/local\/share\/edbian-repo/d' /etc/apt/sources.list || true
sed -i '/file:\/cdrom/d' /etc/apt/sources.list || true
sed -i '/file:\/run\/live/d' /etc/apt/sources.list || true

# Limpiar cache APT (opcional pero recomendable)
apt clean || true

echo "✅ [APT] Repositorios locales eliminados"
EOF

chmod +x "$CLEAN_HOOK"



# ==================================================
# 📝 CONTRASEÑA ROOT
# ==================================================
echo "👤 [USER] Añadir contraseña root en instalador"
CALAMARES_USERS="config/includes.chroot/etc/calamares/modules/users.conf"

mkdir -p "$(dirname "$CALAMARES_USERS")"

cat > "$CALAMARES_USERS" << 'EOF'
setRootPassword: true
doAutologin: false
EOF



# ==================================================
# 🧑‍💻 CALAMARES – USUARIOS Y GRUPOS (CORRECTO)
# ==================================================
echo "🧑‍💻 [CALAMARES] Configuración de usuarios y grupos"

CALAMARES_USERS="config/includes.chroot/etc/calamares/modules/users.conf"

mkdir -p "$(dirname "$CALAMARES_USERS")"

cat > "$CALAMARES_USERS" << 'EOF'
setRootPassword: true
doAutologin: false

defaultGroups:
  - sudo
  - audio
  - video
  - plugdev
  - netdev
  - lp
  - cdrom
EOF



# ==================================================
# 🧹 CALAMARES – LIMPIEZA POST-INSTALL
# ==================================================
echo "🧹 [CALAMARES] Eliminando Calamares del sistema instalado"

CALAMARES_POST_SCRIPT="config/includes.chroot/usr/local/bin/calamares-cleanup.sh"

mkdir -p "$(dirname "$CALAMARES_POST_SCRIPT")"

cat > config/includes.chroot/usr/local/bin/calamares-cleanup.sh << 'EOF'
#!/bin/sh
set -e

TARGET="/target"

echo "🧹 [POST-INSTALL] Eliminando Calamares del sistema instalado..."

chroot "$TARGET" apt purge -y calamares calamares-settings-debian || true

rm -f "$TARGET/usr/share/applications/calamares.desktop"
rm -f "$TARGET/etc/xdg/autostart/calamares.desktop"

chroot "$TARGET" apt autoremove -y || true
chroot "$TARGET" apt clean || true

echo "✅ Calamares eliminado del sistema instalado"
EOF

chmod +x config/includes.chroot/usr/local/bin/calamares-cleanup.sh

chmod +x "$CALAMARES_POST_SCRIPT"



# ==================================================
# 🧹 CALAMARES – REGISTRAR POST-INSTALL (shellprocess)
# ==================================================
echo "🧹 [CALAMARES] Registrando shellprocess post-install"

CALAMARES_SHELLPROCESS="config/includes.chroot/etc/calamares/modules/shellprocess.conf"

mkdir -p "$(dirname "$CALAMARES_SHELLPROCESS")"

cat > config/includes.chroot/etc/calamares/modules/shellprocess.conf << 'EOF'
- type: shellprocess
  name: "Remove Calamares"
  interface: false
  command: |
    /usr/local/bin/calamares-cleanup.sh
EOF


# ==================================================
# 📋 CALAMARES – ORDEN DE MÓDULOS (modules.conf)
# ==================================================
echo "📋 [CALAMARES] Asegurando ejecución de shellprocess"

CALAMARES_MODULES_CONF="config/includes.chroot/etc/calamares/modules.conf"

mkdir -p "$(dirname "$CALAMARES_MODULES_CONF")"

cat > "$CALAMARES_MODULES_CONF" << 'EOF'
modules:
  - welcome
  - locale
  - keyboard
  - partition
  - users
  - summary
  - install
  - shellprocess
EOF



# ==================================================
# 📝 PRESEED (SUDO USUARIO)
# ==================================================
#echo "📝 Preseed + 👤 [USER] Audio groups"
#mkdir -p config/includes.binary
#cat > config/includes.binary/preseed.cfg << EOF
#d-i passwd/user-default-groups string audio video sudo plugdev netdev
#EOF


# ==================================================
# 🥾 GRUB
# ==================================================
echo "🥾 GRUB"
mkdir -p config/includes.binary/boot/grub
cat > config/includes.binary/boot/grub/grub.cfg << EOF
set timeout=5

menuentry "Live edbian XFCE" {
 linux /live/vmlinuz boot=live quiet splash threadirqs preempt=full
 initrd /live/initrd.img
}

menuentry "Instalar edbian (Calamares)" {
 linux /live/vmlinuz boot=live quiet splash threadirqs preempt=full calamares
 initrd /live/initrd.img
}
EOF

# ==================================================
# 🚀 BUILD
# ==================================================
echo "🚀 Build"
sudo lb build
echo "✅ ISO lista"

