# portfolio-workspace

Separé el contenido, la interfaz y la operación del portafolio en tres repositorios. Este workspace reúne los servicios para trabajar con ellos bajo un mismo origen HTTP; no contiene una tercera aplicación.

La API gobierna el contenido profesional y recibe contactos. La SPA decide cómo presentar esos datos. Este repositorio mantiene Docker, el enrutamiento de Nginx y los scripts comunes. La separación permite cambiar la interfaz sin tocar la persistencia y construir imágenes independientes para cada servicio. A cambio, obliga a tratar el contrato JSON como una frontera: cambiar una respuesta requiere revisar también al consumidor.

| Repositorio | Responsabilidad |
| --- | --- |
| [portfolio-workspace](https://github.com/FelixSaucedo/portfolio-workspace) | Red, contenedores, configuración de despliegue y operación conjunta. |
| [felixsaucedo-api](https://github.com/FelixSaucedo/felixsaucedo-api) | Laravel 13, contenido bilingüe, tokens de diseño y recepción de contactos. |
| [felixsaucedo-ui](https://github.com/FelixSaucedo/felixsaucedo-ui) | Vue 3.5, presentación, preferencias de usuario y formulario. |

Los directorios `felixsaucedo-api/` y `felixsaucedo-ui/` están excluidos del Git raíz. Son clones independientes, no submódulos. Cada uno conserva sus lockfiles, historial y Dockerfiles. La coordinación de versiones es explícita; este workspace no fija un commit de los otros dos repositorios.

## Una entrada HTTP, dos runtimes

Elegí Nginx como entrada común para conservar URLs relativas en el navegador y evitar configurar CORS para el flujo habitual. La API corre en PHP-FPM; no necesita un servidor HTTP de desarrollo adicional.

```text
Navegador
    |
    v
Nginx gateway :80
    |
    +-- /api/* ---- FastCGI ---> PHP-FPM :9000 / Laravel ---> MySQL 8.4
    |
    +-- /storage/* -----------> almacenamiento público
    |
    +-- /* ------------------> UI
                                desarrollo: Vite :5173 + HMR
                                producción: Nginx :80 + dist/
```

[`nginx/default.conf`](nginx/default.conf) conecta el desarrollo con Vite y permite WebSocket para HMR. [`nginx/default.prod.conf`](nginx/default.prod.conf) conecta con la imagen del frontend compilado. En producción, otro Nginx dentro de esa imagen sirve los archivos y resuelve las rutas de la SPA. Ambos gateways comparten [`nginx/common.conf`](nginx/common.conf): rutas de API y storage, compresión gzip, `X-Content-Type-Options: nosniff` y `X-Frame-Options: SAMEORIGIN`, incluidos los errores HTTP.

El Compose local monta los fuentes y conserva `vendor` y `node_modules` en volúmenes. MySQL tiene su propio volumen y la API espera a que una consulta SQL con el usuario de la aplicación tenga éxito. Solo el gateway publica un puerto al host. PHP-FPM y MySQL se acceden por la red Docker; la API usa `db:3306`. Para inspeccionar la base, utiliza el cliente dentro del contenedor con `docker compose exec db mysql -u portfolio_user -p portfolio_db`.

La configuración compartida evita que las rutas y los headers de desarrollo diverjan de producción. Gzip usa nivel 5 y un umbral de 1024 bytes para HTML, JSON y otros formatos de texto; comprimir respuestas pequeñas aportaría poco frente al trabajo adicional.

## Inicialización desde los repositorios

Requisitos: Git, Docker Engine con Compose, o Docker Desktop con contenedores Linux. PHP, Composer y Node se ejecutan dentro de los contenedores.

```bash
git clone https://github.com/FelixSaucedo/portfolio-workspace.git
cd portfolio-workspace
git clone https://github.com/FelixSaucedo/felixsaucedo-api.git
git clone https://github.com/FelixSaucedo/felixsaucedo-ui.git
cp felixsaucedo-api/.env.example felixsaucedo-api/.env
```

Antes de iniciar, configura en `felixsaucedo-api/.env` las credenciales iniciales `PORTFOLIO_ADMIN_NAME`, `PORTFOLIO_ADMIN_EMAIL` y `PORTFOLIO_ADMIN_PASSWORD`. El seeder exige una contraseña de al menos 16 caracteres. Las credenciales de muestra y de MySQL local no son valores de producción.

```bash
docker compose up -d --build
```

La primera ejecución instala las dependencias. Espera a que `docker compose logs api ui` muestre PHP-FPM y Vite disponibles antes de ejecutar Artisan.

```bash
docker compose exec api php artisan key:generate --no-interaction
docker compose exec api php artisan migrate:fresh --seed --no-interaction
```

`migrate:fresh` elimina todas las tablas: este paso está pensado para una base local desechable. En una base que deba conservarse, aplica `migrate` y decide por separado si corresponde ejecutar el seeder. Genera `APP_KEY` solo al inicializar el entorno; conserva la clave existente en los siguientes arranques.

El sitio queda en `http://localhost`; el contenido, en `/api/v1/portfolio?lang=es` o `?lang=en`.

Los scripts `init-projects.sh` y `init-projects.bat` pertenecen al flujo de scaffolding, no al flujo de clonación anterior. Crean proyectos cuando faltan y reaplican plantillas de infraestructura. Detienen la ejecución si encuentran una carpeta API sin `vendor/autoload.php` o una UI sin `package.json`; no eliminan proyectos existentes. Una API recién clonada sin dependencias cumple esa condición: usa el flujo de clonación anterior para instalar el portafolio.

## Verificación y operación local

Desde la raíz:

```bash
docker compose config --quiet
docker compose exec gateway nginx -t
docker compose ps
docker compose exec api php artisan test --compact tests/Feature/PortfolioApiTest.php
docker compose exec ui node --experimental-strip-types --test tests/portfolio-contract.test.mjs
docker compose exec ui npm run build
```

Las pruebas del frontend consultan la API real por la red Docker. Las de Laravel usan SQLite en memoria; la ejecución de migraciones sobre MySQL es una comprobación distinta. Los README de cada servicio explican su contrato y sus verificaciones.

Cada repositorio también tiene un Compose autónomo: API en `localhost:8080` y UI en `localhost:5173`. Detén el stack raíz antes de usarlos para evitar conflictos de puertos. El proxy de Vite autónomo apunta por defecto a `host.docker.internal:8080`; fuera de Docker Desktop puede requerir `API_PROXY_TARGET` con una dirección alcanzable.

## Producción

[`docker-compose.prod.yml`](docker-compose.prod.yml) usa builds por etapas, dependencias incluidas en las imágenes y fuentes sin bind mounts. El frontend sirve `dist/`; no ejecuta Vite. La API instala dependencias sin paquetes de desarrollo y cachea la configuración al arrancar.

```bash
cp .env.production.example .env.production
```

Configura `APP_KEY`, `APP_URL`, las contraseñas de MySQL y las credenciales iniciales del administrador antes de continuar. Usa una clave de aplicación propia del entorno y consérvala entre despliegues.

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml build api
docker compose --env-file .env.production -f docker-compose.prod.yml build ui
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --no-build
docker compose --env-file .env.production -f docker-compose.prod.yml exec --user www-data api php artisan migrate --force --no-interaction
```

No combines este Compose con el de desarrollo. `API_IMAGE` y `UI_IMAGE` permiten seleccionar imágenes construidas fuera del servidor. El gateway publica únicamente el puerto 80; TLS no está configurado en estos archivos.

Los límites de memoria suman 1280 MiB para los cuatro servicios. PHP-FPM admite hasta tres procesos y MySQL usa un buffer pool de 128 MiB. Es una configuración contenida para un servidor pequeño, no una estimación de capacidad bajo carga. Cache y sesiones usan archivos, y las colas son síncronas: escalar a varias réplicas requeriría revisar esas decisiones.

La API y el Compose no utilizan variables laborales `PORTFOLIO_CAREER_*`. La trayectoria se obtiene exclusivamente de la base de datos.

`docker compose down` conserva los volúmenes. `down -v` los elimina. Cambiar una contraseña en el archivo de entorno tampoco cambia automáticamente el usuario de un volumen MySQL ya inicializado.

## Archivos versionados y datos locales

El workspace versiona la configuración necesaria para reproducir el entorno. El [`.gitignore`](.gitignore) excluye credenciales `.env`, dependencias, builds, cachés locales de Docker, logs, respaldos temporales y dumps de base de datos. Los archivos `.env.example` y `.env.production.example` se conservan como contratos de configuración; los datos persistentes viven en volúmenes Docker.

## Sincronización de los tres repositorios

[`sync-repos.sh`](sync-repos.sh) simplifica la publicación de cambios ya revisados:

```bash
./sync-repos.sh "docs: actualizar arquitectura y operación"
```

El script localiza el workspace desde su propia ruta, independientemente del directorio desde el que se invoque. Antes de modificar nada, comprueba los tres repositorios, la existencia del remoto `origin`, una rama activa y la ausencia de conflictos, merges o rebases incompletos.

Recorre workspace, API y UI en ese orden. Si encuentra cambios, ejecuta `git add --all` y crea un commit con el mensaje indicado. Después hace `git push origin HEAD`, incluso cuando el árbol ya estaba limpio, para poder reintentar un push pendiente. Usa `set -euo pipefail` y termina ante el primer error.

El script incluye todos los cambios pendientes, también archivos nuevos y eliminados. Revisa los tres diffs antes de usarlo. No hace pull, no resuelve conflictos y no publica los tres repositorios de forma atómica: un push anterior puede haber terminado cuando falla el siguiente.
