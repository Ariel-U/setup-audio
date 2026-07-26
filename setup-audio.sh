#!/usr/bin/env bash

AZUL='\033[0;34m'
NC='\033[0m'
# Crar el grupo 'audio' y agreagar usuario.
echo -e "${AZUL}Agregando usuario al grupo audio${NC}"
grupo="audio"

if grep -q "^$grupo:" /etc/group; then
    echo "El grupo $grupo ya existe."
else
    echo "El grupo $grupo no existe. Creándolo..."
    sudo groupadd $grupo
    echo "Grupo $grupo creado."
fi

sudo usermod -a -G "$grupo" "$USER"

# Aumentar el límite de sguridad para audio en tiempo real.
echo -e "${AZUL}Aumentando limite de memoria para audio en tiempo real${NC}"

sudo cp /etc/security/limits.conf /etc/security/limits.conf.bak
sudo sed -i '/^@audio - rtprio/d' /etc/security/limits.conf
sudo sed -i '/^@audio - memlock/d' /etc/security/limits.conf
echo '@audio - rtprio 90
@audio - memlock unlimited' | sudo tee -a /etc/security/limits.conf

# aumentar el número de archivos que se pueden monitorear
# no es estrictamente necesario pero podría ayudar en algunos sistemas
sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak

sudo sed -i '/fs\.inotify\.max_user_watches=/d' /etc/sysctl.conf
echo 'fs.inotify.max_user_watches=600000' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# modificar latencia de pipewire
saltar=false
echo -e "${AZUL}Verificando pipewire.conf${NC}"
if [ -f "$HOME/.config/pipewire/pipewire.conf" ]; then
    echo "El archivo $HOME/.config/pipewire/pipewire.conf ya existe."
    echo "   ¿sobrescribirlo? (s/N)"
    read -r respuesta
    if [[ "$respuesta" != "s" ]]; then
        echo "manteniendo la configuración existente."
        saltar=true
    fi
fi

if [[ "$saltar" != true ]]; then
	# Crear directorio si no existe
	mkdir -p $HOME/.config/pipewire

	# copia de la configuración base del sistema
	cp -f /etc/pipewire/pipewire.conf $HOME/.config/pipewire/pipewire.conf

	if ! grep -q 'default.clock.max-quantum' "$HOME/.config/pipewire/pipewire.conf"; then
    	echo -e "${AZUL}Estableciendo latencia en 512 samples y tasa de muestreo a 48000 Hz${NC}"
    	echo 'default.clock.max-quantum   = 512
	default.clock.min-quantum   = 128
	default.clock.rate          = 48000' | tee -a "$HOME/.config/pipewire/pipewire.conf"
	systemctl --user restart pipewire.service # reiniciar servicios de audio
	fi
fi


# final
echo -e "${AZUL}Todo Listorti${NC}"
echo "Cerrar sesión o reiniciar para que los cambios tengan efecto"
echo ""
echo "Tip: para cambiar la latencia temporalmente ejecuta 'pw-metadata -n settings 0 clock.force-quantum <latencia>'"

