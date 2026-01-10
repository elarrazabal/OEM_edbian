# OEM_edbian
Edbian creationOEM script

Este script genera un respin de Debian 13 añadiendo los paquetes que se deseen y copiando la configuración personalizada de escritorio.
Está pensado para un escritorio XFCE, pero se puede adaptar a otros escritorios modificando las rutas de configuración.

## Objetivo
El objetivo de Edbian 1.0 es la creación de una adaptación de Debian 13 que cumpla:

- Instalación similar a Debian 13
- Kernel RT para ediciones de video y música
- Usuario creado durante la instalación con permisos de root
- Entorno de escritorio XFCE mejorado con whisker menu, barra superior de herramientas con reloj, plank y picom
- Paquetes adicionales como herramientas de respaldo, gestor de paquetes nala, edición de imágenes, edición de sonido, navegador chromium...
- Pipewire incluido
- Balena Etcher incluido como paquete instalado, ya que el appImage oficial no funciona en Debian 13.
- Aplicación adicional de instalación de paquetes
- Tienda de aplicaciones visual como Discover

## MVP 
Se considera el MVP a una versión que contiene lo anteriormente mencionado, aunque está aun lejos de su versión final

## Proyecto Edbian
El proyecto cumple con un doble objetivo:
- Creación de un respin de debian más cómodo de usar para el usuario final
- Ejecución del proyecto basado en el mindset Agile, creciendo dicho sistema en función de las necesidades de los usuarios

## BUGS conocidos
- [x] Kernel RT instalado
- [x] Teclado e idioma en castellano
- [x] Plank arranca al inicio
- [x] Picom arranca al inicio
- [ ] Fondo de escritorio personoalizado
- [ ] Usuario incluido en grupo sudoers
- [ ] Paquetes .deb personalizados instalados
