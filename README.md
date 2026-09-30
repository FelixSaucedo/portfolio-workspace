# Portfolio: Laravel + Vue 3 + MySQL 8.4 en Docker

La raiz es `sitio/`. No necesitas PHP, Composer, Node, npm ni Git en el host. Docker Desktop debe estar activo con contenedores Linux y soporte WSL2.

## Inicializacion

Linux/WSL:

```sh
cd /home/felix/projectos/sitio
bash init-projects.sh
docker compose up -d --build
```

Windows CMD:

```bat
cd /d C:\ruta\sitio
init-projects.bat
docker compose up -d --build
```

En PowerShell usa `./init-projects.bat`. Abre http://localhost. Las instalaciones iniciales pueden tardar; revisa `docker compose logs -f api ui`.

Ambos scripts eliminan por completo una API sin `vendor/autoload.php` y una UI sin `package.json`, incluyendo cambios locales o `.git` dentro de esas carpetas incompletas. Los proyectos completos se conservan: no se cambia automaticamente su version de Laravel o Vite. Para obtener el nuevo scaffolding mas reciente debes recrearlos deliberadamente.

El scaffolding Laravel no fija una version: Composer descarga la version estable mas reciente. Usa `--no-install --no-scripts`, configura `platform.php=8.4.0` y luego instala dependencias sin scripts, omitiendo solo las comprobaciones de extensiones que compila el Dockerfile real. PHP 8.4 se usa tanto en dev como prod. Los controles de seguridad de Composer permanecen activos. La seleccion de versiones con `latest` depende del momento de ejecucion; los lockfiles registran la resolucion.

`scripts/configure-env.php` crea `.env` cuando falta y configura `.env` y `.env.example` para MySQL: host `db`, puerto `3306`, base `portfolio_db`, usuario `portfolio_user`, clave local `portfolio_secret`. La APP_KEY existente se conserva. El script reaplica esos valores locales de DB en cada ejecucion; no lo uses sobre un checkout con credenciales de produccion.

Vue se crea con `npm create vite@latest`, Node 22 Alpine y TypeScript. Tailwind v4 se integra con `@tailwindcss/vite`; el CSS incluye `@import "tailwindcss";`. Se eliminan las configuraciones de Tailwind v3 y PostCSS y las dependencias directas `postcss`/`autoprefixer`. La instalacion mantiene dependencias transitivas que otras herramientas necesiten. Vite usa polling y el gateway soporta WebSocket para hot-reload.

Las plantillas completas de ambos repositorios viven en `.docker-templates/` y se copian, incluidos sus archivos ocultos, despues del scaffolding. El script sobrescribe los archivos de infraestructura correspondientes.

## API, dependencias y migraciones

La capa de datos y Sanctum ya están implementados. Consulta `felixsaucedo-api/docs/DATA_LAYER.md` para configurar el administrador y cargar el contenido:

```sh
docker compose exec --user www-data api php artisan migrate --no-interaction
```

Las rutas viven en `felixsaucedo-api/routes/api.php`. El cliente usa `import.meta.env.VITE_API_BASE_URL` con `/api` por defecto. Nginx deriva `/api` al front controller PHP mediante FastCGI y sirve `/storage` desde `storage/app/public`; este gateway no necesita `storage:link`.

```sh
docker compose exec api composer require nombre/paquete
docker compose exec ui npm install nombre-paquete
```

`vendor` y `node_modules` se mantienen en volumenes Docker para acelerar Windows. Los fuentes se montan desde el host. Los archivos creados por el init de Linux pertenecen al UID/GID del usuario; la limpieza usa root dentro de un contenedor. FPM prepara `storage` y `bootstrap/cache` para `www-data`. Ejecuta Artisan como ese usuario cuando escriba archivos.

MySQL local se publica en el puerto 3306, con el nombre `portfolio-db`. Si ya tienes otro servidor usando ese puerto, cambia el puerto del host. La API usa siempre `db:3306` dentro de Docker. Su inicio depende de una consulta SQL exitosa con el usuario de la aplicacion, no solo de que el puerto este abierto.

## Repositorios y ejecucion autonoma

Desde CMD, sin Git local:

```bat
docker run --rm -v "%cd%\felixsaucedo-api:/git" alpine/git init --initial-branch=main
docker run --rm -v "%cd%\felixsaucedo-ui:/git" alpine/git init --initial-branch=main
```

Cada carpeta conserva sus Dockerfiles y Compose. El workspace ignora ambas. Deten el Compose raiz antes de iniciar las instancias autonomas:

```sh
docker compose down
cd felixsaucedo-api
docker compose up -d --build
```

API autonoma: http://localhost:8080/api/..., con su propia base MySQL y volumen. En otra consola, entra en `felixsaucedo-ui` y ejecuta `docker compose up -d --build`: UI en http://localhost:5173. El proxy de Vite usa `host.docker.internal:8080` para `/api` y `/storage`, configurable con `API_PROXY_TARGET`. En Linux fuera de Docker Desktop debes configurar una direccion que alcance al host.

## Lightsail: produccion

Necesitas Docker Engine y Compose en Ubuntu. Transfiere el workspace y ambos proyectos con sus lockfiles, o publica las imagenes desde CI.

```sh
cp .env.production.example .env.production
chmod 600 .env.production
```

Edita `APP_KEY`, `APP_URL`, `DB_PASSWORD` y `MYSQL_ROOT_PASSWORD`. Para generar una clave distinta para produccion:

```sh
docker run --rm php:8.4-cli-alpine php -r 'echo "base64:".base64_encode(random_bytes(32)).PHP_EOL;'
```

Conserva la clave entre despliegues. MySQL inicializa usuarios y claves solo al crear un volumen vacio: editar variables no actualiza usuarios de una base existente.

Usa solo el Compose de produccion; no lo combines con el de desarrollo. Builds secuenciales:

```sh
docker compose --env-file .env.production -f docker-compose.prod.yml build api
docker compose --env-file .env.production -f docker-compose.prod.yml build ui
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --no-build
docker compose --env-file .env.production -f docker-compose.prod.yml exec --user www-data api php artisan migrate --force --no-interaction
```

En un VPS de 2 GB es preferible construir en CI y definir `API_IMAGE`/`UI_IMAGE` para desplegar con `pull` y `up -d --no-build`. Los limites de ejecucion no limitan la memoria de los builds.

Los contenedores tienen limites de 1280 MiB en total: API 640, MySQL 512, UI 64 y gateway 64. FPM tiene tres procesos como maximo y PHP limita cada ejecucion a 128 MB. MySQL usa buffer pool de 128 MB, log buffer de 16 MB, treinta conexiones como maximo y Performance Schema desactivado para reducir RAM. Confirma el consumo bajo carga con `docker stats`.

Produccion sirve Vue compilado desde Nginx y no ejecuta Vite, npm ni Composer al arrancar. Las credenciales vienen del entorno. MySQL no publica el puerto 3306 en produccion; solo el gateway publica el 80. Agrega TLS y un dominio antes de publicar autenticacion. Las colas son sincronas, y sesiones/cache usan archivos; agrega workers y reajusta memoria cuando los necesites.

El volumen `db-data` es exclusivo de MySQL. No montes antiguos volumenes de otra base en `/var/lib/mysql`; no hay una migracion automatica de datos entre motores. Los volumenes anteriores se conservan hasta que decidas retirarlos. Respalda MySQL y `storage` antes de migraciones. `down` conserva los volumenes; `down -v` elimina datos.

## Validacion

```sh
docker compose config --quiet
docker compose --env-file .env.production -f docker-compose.prod.yml config --quiet
```

La comprobacion real de builds, migraciones y hot-reload requiere acceso al daemon Docker y a los registros de paquetes.
