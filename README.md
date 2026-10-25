# Proyecto Final: Servidor Linux Automatizado

**Universidad de El Salvador**
Facultad Multidisciplinaria de Occidente
Departamento de Ingeniería y Arquitectura
Ingeniería en Desarrollo de Software

## Integrantes (Grupo 6)

| Nombre | Carné |
|---|---|
| Bryan Misael Sanchez Ramirez | SR23022 |
| Cesia Mariena Alfaro Hernández | AH23007 |
| Carlos Alfredo Ayala Mejia | AM25008 |
| Daniel Eduardo Yanes Hércules | YH25001 |

---

## Descripción del proyecto

Este proyecto implementa un **servidor Linux automatizado** utilizando tecnologías de contenedores (Docker). Integra administración de sistemas (usuarios, grupos, permisos), automatización de tareas con `cron`, control de versiones con Git/GitHub, virtualización (QEMU/KVM) y despliegue de servidores web con Nginx en contenedores, incluyendo imágenes personalizadas, redes y volúmenes persistentes.

### Entorno

| Elemento | Valor |
|---|---|
| Virtualización | QEMU/KVM (virt-manager) |
| Sistema operativo | Ubuntu 24.04 LTS |
| Nombre del host | `servidor-grupo6` |
| Memoria RAM | 4096 MiB |
| Disco | 20 GB (`/dev/vda2`) |
| Docker | Instalado desde el repositorio oficial de Docker |

### Resumen de servicios

| Contenedor | Imagen | Puerto host → contenedor | Descripción |
|---|---|---|---|
| `nginx-server` | `nginx` (oficial) | 8080 → 80 | Nginx básico, monta `/proyecto/web/` |
| `nginx-server-avanzado` | `servidor-grupo6` | 8081 → 80 | Imagen personalizada con Dockerfile |
| `nginx-red` | `nginx` (oficial) | 8082 → 80 | Conectado a la red `red-proyecto` |
| `nginx-volumen` | `nginx` (oficial) | 8083 → 80 | Usa el volumen persistente `volumen-web` |

### Estructura del proyecto

```
/proyecto/
├── Dockerfile
├── .dockerignore
├── README.md
├── captura/            # Evidencias del proyecto (capturas)
├── datos/              # Archivos de configuración (grupo: soporte)
├── scripts/
│   └── reporte_sistema.sh
└── web/                # Archivos del sitio web (grupo: web)
    └── index.html
```

> Nota: el directorio de evidencias se llama `capturas/` en el servidor.

---

## Pasos realizados

### 1. Preparación del entorno servidor

#### 1.1 Nombre del host y especificaciones de la VM

La máquina virtual se creó en QEMU/KVM con el nombre `servidor-grupo6`, Ubuntu 24.04 LTS, 4096 MiB de RAM y 20 GB de disco. Se verifica con:

```bash
hostname
df -h
```

#### 1.2 Grupos y usuarios

```bash
# Grupos
sudo groupadd soporte
sudo groupadd web

# Usuarios
sudo useradd -m -s /bin/bash adminsys
sudo useradd -m -s /bin/bash tecnico
sudo useradd -m -s /bin/bash visitante

# Asignación a grupos
sudo usermod -aG sudo adminsys        # adminsys con privilegios sudo
sudo usermod -aG soporte tecnico      # tecnico pertenece a soporte
sudo usermod -aG web visitante        # visitante pertenece a web
```

Verificación:

```bash
cat /etc/group | grep -E "soporte|web"
cut -d: -f1 /etc/passwd | grep -E "adminsys|tecnico|visitante"
id adminsys
id tecnico
id visitante
```

#### 1.3 Estructura de directorios y permisos

```bash
# Crear estructura
sudo mkdir -p /proyecto/datos /proyecto/web /proyecto/scripts /proyecto/capturas

# Asignar grupos propietarios
sudo chgrp soporte /proyecto/datos/
sudo chgrp web /proyecto/web/

# Activar SGID para que los archivos nuevos hereden el grupo del directorio
sudo chmod g+s /proyecto/datos/
sudo chmod g+s /proyecto/web/
```

Verificación (debe aparecer la `s` en los permisos de grupo, por ejemplo `drwxr-sr-x`):

```bash
ls -la /proyecto
ls -ld /proyecto/datos/ /proyecto/web/
```

---

### 2. Automatización y monitoreo

#### 2.1 Instalación de Docker

El script de monitoreo cuenta contenedores Docker, por lo que se instala Docker primero (ver sección 4 para el detalle).

#### 2.2 Script de monitoreo del sistema

Se crea el directorio de logs y se asigna a `adminsys`:

```bash
sudo mkdir -p /var/log/proyecto
sudo chown adminsys:adminsys /var/log/proyecto
ls -ld /var/log/proyecto
```

Se crea el script `/proyecto/scripts/reporte_sistema.sh`:

```bash
sudo nano /proyecto/scripts/reporte_sistema.sh
```

Contenido:

```bash
#!/bin/bash

echo "========================================"
echo "      REPORTE DE ESTADO DEL SISTEMA     "
echo "========================================"

echo "Fecha y hora actual: $(date)"

echo "Nombre del host: $(hostname)"

USUARIOS_CONECTADOS=$(who | wc -l)
echo "Número de usuarios conectados: $USUARIOS_CONECTADOS"

ESPACIO_LIBRE=$(df -h / | awk 'NR==2 {print $4}')
echo "Espacio libre en el disco principal: $ESPACIO_LIBRE"

RAM_DISPONIBLE=$(free -h | awk '/^Mem:/ {print $7}')
echo "Memoria RAM disponible: $RAM_DISPONIBLE"

CONTENEDORES_ACTIVOS=$(docker ps -q | wc -l)
echo "Número de contenedores Docker activos: $CONTENEDORES_ACTIVOS"

echo "========================================"
```

Permisos de ejecución:

```bash
sudo chmod +x /proyecto/scripts/reporte_sistema.sh
```

#### 2.3 Automatización con cron

```bash
sudo crontab -e
```

Se agrega la siguiente línea para ejecutar el script cada 30 minutos y guardar la salida en el log:

```cron
*/30 * * * * /proyecto/scripts/reporte_sistema.sh >> /var/log/proyecto/reporte_sistema.log 2>&1
```

Verificación de que el registro se actualiza:

```bash
sudo tail -n 20 /var/log/proyecto/reporte_sistema.log
```

---

### 3. Control de versiones (Git y GitHub)

Inicialización del repositorio local en `/proyecto/` y primer commit:

```bash
cd /proyecto
git init
git add .
git commit -m "Primer commit: estructura del proyecto"
```

Creación del repositorio remoto en GitHub con el nombre `proyecto-linux-grupo6` y subida del código:

```bash
git branch -M main
git remote add origin https://github.com/<usuario>/proyecto-linux-grupo6.git
git push -u origin main
```

Se agregó este `README.md` con la descripción y los pasos de instalación, y se hizo un commit posterior:

```bash
git add README.md
git commit -m "Agregar README con documentación del proyecto"
git push
```

---

### 4. Docker

#### 4.1 Instalación y configuración

```bash
# Actualizar lista de paquetes
sudo apt update

# Dependencias
sudo apt install ca-certificates curl

# Directorio de llaves
sudo install -m 0755 -d /etc/apt/keyrings

# Llave GPG oficial de Docker
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Repositorio oficial de Docker
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Actualizar e instalar
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Habilitar e iniciar el servicio
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker
```

Agregar usuarios al grupo `docker` para usarlo sin `sudo`:

```bash
sudo usermod -aG docker adminsys
sudo usermod -aG docker tecnico
```

Verificación:

```bash
id adminsys
id tecnico
docker ps        # ejecutado como adminsys y como tecnico, sin sudo
```

#### 4.2 Verificación inicial

```bash
sudo docker run hello-world
sudo docker ps
```

---

### 5. Servidor web containerizado (Nginx básico)

#### 5.1 Página web

```bash
cd /proyecto/web
vim index.html
```

Se creó un `index.html` personalizado ("Proyecto Final – Introducción al Software Libre – Grupo 6") con estilos propios y un contador interactivo en JavaScript.

#### 5.2 Contenedor Nginx básico

```bash
sudo docker run -d --name nginx-server -p 8080:80 -v /proyecto/web/:/usr/share/nginx/html nginx
```

- `-d`: segundo plano (detached)
- `-p 8080:80`: puerto 8080 del host → puerto 80 del contenedor
- `-v`: monta `/proyecto/web/` en `/usr/share/nginx/html`

#### 5.3 Verificación

```bash
sudo docker ps
sudo docker logs nginx-server
curl -I http://localhost:8080
```

También se accede desde el navegador en `http://localhost:8080`.

---

### 6. Docker avanzado

#### 6.1 Dockerfile personalizado

Archivo `/proyecto/Dockerfile`:

```dockerfile
FROM nginx:latest

COPY web/ /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

Archivo `/proyecto/.dockerignore` (excluye lo que no es necesario en la imagen):

```
# Directorio de Git
.git/

# Directorios adicionales excluidos
capturas/
datos/
scripts/
```

Construcción de la imagen:

```bash
cd /proyecto
sudo docker build -t servidor-grupo6 .
sudo docker images
```

#### 6.2 Contenedor con imagen personalizada

```bash
sudo docker run -d --name nginx-server-avanzado -p 8081:80 servidor-grupo6
sudo docker ps
sudo docker logs nginx-server-avanzado
curl -I http://localhost:8081
```

#### Comparación con el contenedor Nginx oficial

| Aspecto | `nginx-server` (básico) | `nginx-server-avanzado` (personalizado) |
|---|---|---|
| Imagen | `nginx` oficial | `servidor-grupo6` (construida con Dockerfile) |
| Contenido web | Montado desde el host con `-v` | Copiado dentro de la imagen con `COPY` |
| Cambios en `index.html` | Se reflejan de inmediato | Requieren reconstruir la imagen |
| Portabilidad | Depende del directorio del host | Autocontenida, se puede distribuir |
| Puerto | 8080 | 8081 |

Ambos sirven la misma página y funcionan correctamente.

---

### 7. Redes y volúmenes Docker

#### 7.1 Red personalizada

```bash
sudo docker network create red-proyecto
sudo docker network ls

sudo docker run -d --name nginx-red --network red-proyecto -p 8082:80 nginx
sudo docker ps

# Verificar que el contenedor está conectado a la red
sudo docker network inspect red-proyecto
curl -I http://localhost:8082
```

#### 7.2 Volumen persistente

```bash
sudo docker volume create volumen-web

sudo docker run -d --name nginx-volumen -p 8083:80 -v volumen-web:/usr/share/nginx/html nginx
sudo docker ps

# Verificar el volumen y el montaje
sudo docker volume inspect volumen-web
sudo docker inspect nginx-volumen --format '{{json .Mounts}}'
curl -I http://localhost:8083
```

**Prueba de persistencia:**

```bash
# 1. Sobrescribir el index.html dentro del volumen
sudo docker exec nginx-volumen sh -c 'echo "<h1>Volumen persistente - Grupo 6</h1>" > /usr/share/nginx/html/index.html'
curl http://localhost:8083

# 2. Eliminar el contenedor (el volumen se conserva)
sudo docker rm -f nginx-volumen
curl http://localhost:8083     # falla: el contenedor ya no existe

# 3. Crear otro contenedor con el mismo volumen
sudo docker run -d --name nginx-volumen -p 8083:80 -v volumen-web:/usr/share/nginx/html nginx
curl http://localhost:8083     # devuelve: <h1>Volumen persistente - Grupo 6</h1>
```

---

### 8. Pruebas y verificación final

#### 8.1 Pruebas de conectividad con Alpine

Contenedor Alpine **dentro** de `red-proyecto` (el ping funciona por resolución de nombres):

```bash
sudo docker run -it --rm --name alpine-test --network red-proyecto alpine ping -c 4 nginx-red
```

Resultado: 4 paquetes transmitidos, 4 recibidos, 0% de pérdida.

Contenedor Alpine **fuera** de la red personalizada (red `bridge` por defecto), el ping falla porque no resuelve el nombre del contenedor:

```bash
sudo docker run -it --rm alpine ping -c 2 nginx-red
# ping: bad address 'nginx-red'
```

#### 8.2 Verificación integral

```bash
# Contenedores en ejecución
sudo docker ps

# Servicios web en sus puertos
curl -I http://localhost:8080
curl -I http://localhost:8081
curl -I http://localhost:8082
curl -I http://localhost:8083

# Script de monitoreo ejecutándose cada 30 minutos
sudo tail -n 20 /var/log/proyecto/reporte_sistema.log

# Repositorio Git actualizado
cd /proyecto
git status
git log --oneline
```

---

## Resumen de verificación

| Servicio | URL | Estado esperado |
|---|---|---|
| Nginx básico | `http://localhost:8080` | Página "Proyecto Final – Grupo 6" |
| Nginx avanzado | `http://localhost:8081` | Página "Proyecto Final – Grupo 6" |
| Nginx en red personalizada | `http://localhost:8082` | Nginx responde 200 OK |
| Nginx con volumen | `http://localhost:8083` | `Volumen persistente - Grupo 6` |
| Monitoreo (cron) | `/var/log/proyecto/reporte_sistema.log` | Nuevo reporte cada 30 minutos |

---

## Conclusiones

Se implementó un servidor Linux completamente funcional y automatizado: usuarios y permisos configurados con herencia de grupo (SGID), monitoreo periódico con `cron`, Docker instalado desde su repositorio oficial y cuatro servidores Nginx desplegados en contenedores (oficial con bind mount, imagen personalizada, red dedicada y volumen persistente). Las pruebas con Alpine confirmaron el aislamiento y la resolución de nombres de las redes de Docker, y la prueba de persistencia demostró que los datos del volumen sobreviven a la eliminación del contenedor.

---
