# PR0102 - Instalación de Webmin en Ubuntu Server
## 1. Introducción

[Webmin](https://webmin.com/) es una herramienta de administración de sistemas Linux a través de una interfaz web. 
Permite gestionar usuarios, servicios, paquetes, discos o el cortafuegos desde el navegador, sin tener que escribir 
cada comando en la terminal.

El objetivo de esta práctica es instalar y configurar Webmin en un servidor Ubuntu Server que se ejecuta en una máquina 
virtual de VirtualBox, automatizando todo el proceso con scripts de Bash y conectándonos al servidor de forma remota mediante SSH.

## 2. Arquitectura web con un único servidor

En esta práctica se trabaja con una arquitectura basada en un único servidor: la aplicación se instala y se ejecuta localmente en 
una sola máquina.

**Ventajas**

- Es una solución sencilla de implementar.
- Es adecuada para aplicaciones que solo van a ejecutar una única instancia.

**Inconvenientes**
- Es la solución menos eficiente, ya que toda la carga recae en un único equipo y no hay redundancia: si el servidor cae, el servicio
  deja de estar disponible.

## 3. Entorno de trabajo

| Elemento | Descripción |
|---|---|
| Anfitrión | Windows con VirtualBox, navegador web y cliente SSH (PowerShell) |
| Servidor | Máquina virtual con Ubuntu Server |
| Adaptador 1 (`enp0s3`) | NAT · IP por DHCP (`10.0.2.15/24`) · da acceso a internet al servidor |
| Adaptador 2 (`enp0s8`) | Solo-anfitrión · IP fija `192.168.0.10/24` · comunica Windows con Ubuntu |
| IP de Windows (solo-anfitrión) | `192.168.0.1/24` |

```
          Internet
             │
     Adaptador 1 · NAT
             │
┌────────────┴─────────────┐
│   Ubuntu Server (VM)     │
│  enp0s3 → 10.0.2.15/24   │
│  enp0s8 → 192.168.0.10/24│
└────────────┬─────────────┘
             │
 Adaptador 2 · solo-anfitrión
             │
   Windows (anfitrión)
   192.168.0.1/24
```

Se usan dos adaptadores porque cada uno cubre una necesidad distinta: la **NAT** permite que Ubuntu descargue paquetes 
de internet (necesario para instalar Webmin con `apt`), y la red **solo-anfitrión** permite que Windows llegue a Ubuntu 
para conectarse por SSH y abrir Webmin en el navegador.

### Comprobación de la red

En el servidor, `ip a` muestra la IP fija en `enp0s8`:

```bash
ip a
```

<image src="imagenes/imagen1.png">

Desde el `cmd` de Windows se comprueba que el servidor responde:

```
ping 192.168.0.10
```

<image src="imagenes/imagen2.png">

## 4. Estructura del repositorio

```
.
├── README.md
├── imagenes
└── scripts
    ├── .env.example
    └── webmin-install.sh
```

| Archivo | Función |
|---|---|
| `README.md` | Este documento técnico |
| `imagenes/` | Capturas de pantalla del proceso |
| `scripts/webmin-install.sh` | Script que automatiza la instalación y configuración de Webmin |
| `scripts/.env` | Variables de configuración reales (contraseña no incluida)|

## 5. Preparación del servidor: SSH

Según el enunciado, el servicio SSH debe estar instalado, configurado y activo en el servidor antes de comenzar, ya que toda la práctica se realiza en remoto desde el cliente Windows. Desde la consola de la máquina virtual se instala el servidor SSH y se deja activado:

```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh
```

- `openssh-server` es el paquete que permite al servidor aceptar conexiones SSH.
- `systemctl enable --now` arranca el servicio en ese momento y hace que se inicie solo en cada arranque del sistema.

En la salida se comprueba que el servicio está en estado `active (running)` y que escucha conexiones en el puerto 22:

<image src=imagen3.png>

A continuación, desde PowerShell en Windows, se abre la conexión con el servidor a través de la red solo-anfitrión:

```powershell
ssh alumno@192.168.0.10
```

La primera vez, el cliente pide confirmar la huella (*fingerprint*) del servidor, que queda guardada para las siguientes conexiones. Tras introducir la contraseña, se obtiene una terminal del servidor:

!<image src="imagen4.png>

A partir de este punto, todos los comandos del servidor se ejecutan desde esta sesión SSH.

## 6. Scripts de automatización

### 6.1. Archivo `.env`

Para que el script no tenga valores escritos directamente en su código, toda la configuración se guarda aparte en el archivo `.env`. 
El script lo carga al empezar con la orden `source`, y a partir de ese momento puede usar cada variable como si la hubiera definido él mismo.

La ventaja de trabajar así es que, si en otro servidor cambian la IP, el puerto o la contraseña, basta con editar el `.env`: el script sigue siendo el mismo y no hay que tocar su lógica.

```bash
SERVER_IP=192.168.0.10
WEBMIN_PORT=10000
WEBMIN_ROOT_PASSWORD=********
WEBMIN_REPO_URL=https://download.webmin.com/download/newkey/repository
WEBMIN_KEY_URL=https://download.webmin.com/developers-key.asc
```

| Variable | Para qué la usa el script |
|---|---|
| `SERVER_IP` | Mostrar al final la dirección desde la que acceder a Webmin |
| `WEBMIN_PORT` | Abrir en el cortafuegos el puerto por el que escucha Webmin |
| `WEBMIN_ROOT_PASSWORD` | Asignar la contraseña al usuario `root` de Webmin |
| `WEBMIN_REPO_URL` | Indicar a `apt` de dónde descargar Webmin |
| `WEBMIN_KEY_URL` | Descargar la clave que verifica que los paquetes son auténticos |

### 6.2. Script `webmin-install.sh`

Este script automatiza toda la instalación: al ejecutarlo, realiza una tras otra las seis tareas que pide la práctica, sin que haya que escribir cada comando a mano. Se lanza con permisos de administrador, porque instalar paquetes y configurar el cortafuegos son cambios en el sistema:

```bash
sudo ./webmin-install.sh
```

La primera línea del script le indica al sistema qué intérprete debe usar para leerlo, en este caso Bash:

```bash
#!/bin/bash
```

Justo después se activan dos opciones que hacen el script más seguro y más fácil de seguir:

```bash
set -ex
```

| Opción | Qué hace |
|---|---|
| `-e` | Si cualquier comando falla, el script se detiene en ese punto. Así se evita continuar con una instalación incompleta |
| `-x` | Antes de ejecutar cada comando, lo muestra en pantalla. Permite ver en todo momento qué paso se está haciendo |

Antes de empezar con la instalación, el script realiza dos comprobaciones:

1. Que se está ejecutando con `sudo`. Si no, avisa del error y se para.
2. Que existe el archivo `.env` en la misma carpeta. Si falta, también se detiene, ya que sin él no tendría la configuración necesaria.

Si todo está correcto, carga las variables del `.env` y pasa a las seis tareas, que se explican una a una en el apartado 7.

Para poder ejecutarlo, primero se le da permiso de ejecución:

```bash
chmod +x webmin-install.sh
```

<image src="imagen5.png>

## 7. Ejecución del script paso a paso

### 7.1. Ejecución del script

Los scripts se crean directamente en el servidor desde la sesión SSH, con el editor `nano`, dentro de la carpeta `~/scripts`:

```bash
mkdir ~/scripts
cd ~/scripts
nano .env
nano webmin-install.sh
chmod +x webmin-install.sh
```

Una vez creados y con permiso de ejecución, se lanza el script con permisos de administrador:

```bash
sudo ./webmin-install.sh
```

Gracias a la opción `-x`, cada comando aparece en pantalla antes de ejecutarse, así que se puede seguir en directo cada una de las seis tareas que se describen a continuación.

### 7.2. Actualizar los repositorios

```bash
apt update
apt upgrade -y
```

`apt update` descarga la lista actualizada de paquetes disponibles y `apt upgrade` actualiza los que ya están instalados. El servidor accede a internet a través del adaptador NAT.

<image src="imagen6.png>

### 7.3. Instalar las dependencias

```bash
apt install -y software-properties-common apt-transport-https wget gnupg
```

| Paquete | Para qué se usa |
|---|---|
| `software-properties-common` | Herramientas para gestionar repositorios de software |
| `apt-transport-https` | Permite a `apt` descargar paquetes por HTTPS |
| `wget` | Descarga la clave GPG del repositorio |
| `gnupg` | Convierte la clave al formato que usa `apt` |

### 7.4. Añadir el repositorio de Webmin

```bash
wget -qO- "$WEBMIN_KEY_URL" | gpg --dearmor --yes -o /usr/share/keyrings/webmin-developers.gpg

echo "deb [signed-by=/usr/share/keyrings/webmin-developers.gpg] $WEBMIN_REPO_URL stable contrib" \
  > /etc/apt/sources.list.d/webmin.list

apt update
```

1. Se descarga la **clave GPG** de los desarrolladores de Webmin. `apt` la usa para verificar que los paquetes descargados son auténticos y no han sido modificados.
2. Se crea el archivo `/etc/apt/sources.list.d/webmin.list` con la dirección del repositorio. La opción `signed-by` indica qué clave firma ese repositorio.
3. Se vuelve a ejecutar `apt update` para que el sistema conozca los paquetes del nuevo repositorio.

<image src="imagen7.png>

### 7.5. Instalar Webmin

```bash
apt install -y --install-recommends webmin
/usr/share/webmin/changepass.pl /etc/webmin root "$WEBMIN_ROOT_PASSWORD"
```

En Ubuntu la cuenta `root` no está activada, pero es necesario ser `root` en Webmin para modificar la configuración de los servicios. Por eso se asigna una contraseña al usuario `root` de Webmin con el script `changepass.pl`, tomándola de la variable del `.env`.

<image src="imagen8.png>

### 7.6. Configurar el cortafuegos

```bash
ufw allow OpenSSH
ufw allow "$WEBMIN_PORT"/tcp
ufw --force enable
ufw status verbose
```

Se usa UFW (*Uncomplicated Firewall*), el cortafuegos de Ubuntu.

- La regla de **SSH se añade antes de activar el cortafuegos**. Como el script se ejecuta desde una sesión SSH, activar UFW sin esta regla cortaría la conexión.
- Se abre el puerto **10000/tcp**, que es el que usa Webmin.
- `--force` evita que `ufw enable` pida confirmación, para que el script no se detenga esperando una respuesta.

<image src="imagen9.png>

### 7.7. Ejecutar Webmin

```bash
systemctl enable webmin
systemctl restart webmin
systemctl status webmin --no-pager
```

Se habilita el servicio para que arranque con el sistema, se reinicia para aplicar la configuración y se comprueba que está activo (`active (running)`).

<image src="imagen10.png>




