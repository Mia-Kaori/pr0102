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

<image src="imagenes/imagen1.PNG">

Desde el `cmd` de Windows se comprueba que el servidor responde:

```
ping 192.168.0.10
```

<image src="imagenes/imagen2.PNG">
