#!/bin/bash
# =============================================================
#  Práctica 0102 - Instalación automatizada de Webmin
#  Uso: sudo ./webmin-install.sh
# =============================================================

# -e: detiene el script si algún comando falla
# -x: muestra cada comando antes de ejecutarlo
set -ex

# 0. Comprobaciones previas
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: ejecuta el script con sudo: sudo ./webmin-install.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
  echo "ERROR: no existe $SCRIPT_DIR/.env"
  exit 1
fi

source "$SCRIPT_DIR/.env"

# 1. Actualizar los repositorios
apt update
apt upgrade -y

# 2. Instalar las dependencias
apt install -y software-properties-common apt-transport-https wget gnupg

# 3. Añadir el repositorio de Webmin
wget -qO- "$WEBMIN_KEY_URL" | gpg --dearmor --yes -o /usr/share/keyrings/webmin-developers.gpg

echo "deb [signed-by=/usr/share/keyrings/webmin-developers.gpg] $WEBMIN_REPO_URL stable contrib" \
  > /etc/apt/sources.list.d/webmin.list

apt update

# 4. Instalar Webmin
apt install -y --install-recommends webmin

/usr/share/webmin/changepass.pl /etc/webmin root "$WEBMIN_ROOT_PASSWORD"

# 5. Configurar el cortafuegos
# Primero SSH, para no cortar la conexión al activar UFW
ufw allow OpenSSH
ufw allow "$WEBMIN_PORT"/tcp
ufw --force enable
ufw status verbose

# 6. Ejecutar Webmin
systemctl enable webmin
systemctl restart webmin
systemctl status webmin --no-pager

set +x
echo ""
echo "============================================================"
echo " Webmin instalado correctamente"
echo " Accede desde el navegador a: https://$SERVER_IP:$WEBMIN_PORT"
echo " Usuario: root"
echo "============================================================"
