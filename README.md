# portfolio-workspace

Separé mi portafolio en tres repositorios: API, interfaz e infraestructura. Este workspace contiene Docker Compose, Nginx y los scripts para ejecutarlos juntos. Construyo la API y la UI por separado; si cambio el contrato JSON, reviso ambos repositorios.

| Repositorio | Responsabilidad |
| --- | --- |
| [portfolio-workspace](https://github.com/FelixSaucedo/portfolio-workspace) | Docker Compose, gateway Nginx y operación conjunta. |
| [felixsaucedo-api](https://github.com/FelixSaucedo/felixsaucedo-api) | Laravel 13 / PHP 8.4, contenido ES/EN, contactos y correo asíncrono. |
| [felixsaucedo-ui](https://github.com/FelixSaucedo/felixsaucedo-ui) | Vue 3.5 / TypeScript / Vite 8 / Tailwind CSS 4. |

Mantengo API y UI como clones independientes, excluidos del Git raíz. Cada uno conserva su historial y sus dependencias; este workspace no fija sus versiones mediante submódulos.

## Servicios y red

Uso Nginx para servir UI y API bajo el mismo origen y evitar CORS en el flujo habitual. `/api/*` llega a Laravel mediante PHP-FPM, `/storage/*` sirve archivos públicos y el resto llega a la UI. En desarrollo trabajo con Vite y HMR; en producción sirvo la aplicación compilada.

| Servicio | Función |
| --- | --- |
| `gateway` | Nginx, puerto HTTP 80, headers de seguridad y límite API de 64 KB. |
| `api` | PHP-FPM y Laravel. |
| `ui` | Vite con HMR en desarrollo; Nginx y `dist/` en producción. |
| `db` | MySQL 8.4 con volumen persistente. |
| `contact-worker` | Procesa los correos de la cola `contacts`. |
| `contact-scheduler` | Recupera cada minuto los despachos pendientes. |

MySQL local se publica únicamente en `127.0.0.1:3306`, con base `portfolio_db` y usuario `portfolio_user`. La contraseña está en `MYSQL_PASSWORD` del Compose local; Laravel se conecta a `db:3306`. Producción no publica MySQL al host.

## Desarrollo

Ejecuto PHP, Composer y Node en Docker para mantener las versiones del entorno. Para preparar el sitio necesito Git y Docker Compose con contenedores Linux:

```bash
git clone https://github.com/FelixSaucedo/portfolio-workspace.git
cd portfolio-workspace
git clone https://github.com/FelixSaucedo/felixsaucedo-api.git
git clone https://github.com/FelixSaucedo/felixsaucedo-ui.git
cp felixsaucedo-api/.env.example felixsaucedo-api/.env
```

Antes del primer arranque preparo `PORTFOLIO_ADMIN_*` y las credenciales `MAIL_USERNAME` / `MAIL_PASSWORD` de SMTP2GO en el `.env` de la API. El administrador inicial requiere una contraseña de al menos 16 caracteres. Uso `contacto@felixsaucedo.com` como remitente y como destinatario de las notificaciones del sitio.

```bash
docker compose up -d --build db api ui
docker compose exec api php artisan key:generate --no-interaction
docker compose exec api php artisan migrate --no-interaction
docker compose exec api php artisan db:seed --no-interaction
docker compose up -d
```

Genero `APP_KEY` solo en la primera instalación. Artisan requiere que PHP-FPM esté disponible; el sitio se sirve en `http://localhost`.

Para actualizar el esquema o los textos del seeder:

```bash
docker compose exec api php artisan migrate --no-interaction
docker compose exec api php artisan db:seed --class=PortfolioSeeder --no-interaction
```

El seeder sobrescribe sus registros, incluidas las ediciones manuales. Uso `migrate` para actualizar el esquema; `migrate:fresh` y `down -v` eliminan datos.

## Pruebas y correo

```bash
docker compose config --quiet
docker compose exec gateway nginx -t
docker compose exec api php artisan test --compact
docker compose exec api php artisan route:list --no-interaction
docker compose exec ui npm test
docker compose exec ui npm run build
```

Las pruebas Laravel usan una base aislada. Las pruebas de contrato de la UI consultan la API real del stack.

Guardo el contacto antes de encolar la alerta para mí y la confirmación para quien escribe. Si falla la cola, el mensaje queda disponible para recuperar el despacho. La API devuelve `201` con los jobs registrados o `202` con notificaciones pendientes; ninguno confirma entrega SMTP.

```bash
docker compose logs --tail=100 contact-worker contact-scheduler
docker compose exec api php artisan contacts:dispatch-pending --no-interaction
docker compose exec api php artisan queue:failed --no-interaction
docker compose exec api php artisan queue:retry all --no-interaction
```

Tras cambiar configuración de correo o código del worker:

```bash
docker compose exec api php artisan config:clear --no-interaction
docker compose restart contact-worker contact-scheduler
```

## Producción

```bash
cp .env.production.example .env.production
```

En producción conservo una `APP_KEY` permanente y preparo `APP_URL`, las contraseñas de MySQL, `PORTFOLIO_ADMIN_*` y las credenciales SMTP. Separé este Compose del de desarrollo: fuerza `APP_DEBUG=false`, comparte la caché en base de datos e incluye worker y scheduler. La terminación HTTPS se configura fuera de estos archivos.

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml config --quiet
docker compose --env-file .env.production -f docker-compose.prod.yml build api ui
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --no-build db api
docker compose --env-file .env.production -f docker-compose.prod.yml exec --user www-data api php artisan migrate --force --no-interaction
# Solo en la primera instalación:
docker compose --env-file .env.production -f docker-compose.prod.yml exec --user www-data api php artisan db:seed --force --no-interaction
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --no-build
```

Construyo imágenes que incluyen las dependencias y la UI compilada; `API_IMAGE` y `UI_IMAGE` me permiten usar imágenes preparadas fuera del servidor. Conservo los volúmenes y `APP_KEY` entre despliegues. Las credenciales de un MySQL ya inicializado requieren su propia actualización: cambiar `.env.production` no modifica ese usuario.

### Lightsail con Caddy existente

En el servidor uso también `docker-compose.caddy.yml`. El gateway se conecta a la red externa `web` con el alias `felix-portfolio-gateway`; API, UI y MySQL permanecen en la red del portafolio. Este override retira el puerto 80 del host y limita el conjunto a 1 GiB de memoria como máximo. Esos límites no reservan memoria ni cubren el consumo de los builds.

Configuro `APP_URL` y `VITE_SITE_URL` como `https://felixsaucedo.com`, y `CADDY_PROXY_IP` con la IP de Caddy en `web`. Nginx acepta la IP de visitante enviada por ese proxy y comunica HTTPS a PHP-FPM. Si recreo Caddy, compruebo su IP y recreo el gateway si cambió.

```bash
docker inspect caddy --format '{{with index .NetworkSettings.Networks "web"}}{{.IPAddress}}{{end}}'
docker compose --env-file .env.production -f docker-compose.prod.yml -f docker-compose.caddy.yml config --quiet
```

Uso ambos archivos Compose en **todos** los comandos de este despliegue. Construyo `api` y `ui` por separado para reducir el pico de memoria y sigo el orden de migraciones del apartado anterior. Antes de cambiar el dominio compruebo desde Caddy que el gateway sirve `/` y `/api/v1/portfolio`.

En el bloque `felixsaucedo.com` sustituyo el servidor estático y la redirección de rutas por `reverse_proxy felix-portfolio-gateway:80`. Conservo el bloque de `entre-nosotros` y redirijo `www` al dominio principal preservando `{uri}`. Respaldo el Caddyfile, valido la nueva configuración y la recargo; para volver al HTML anterior restauro ese archivo y lo recargo. No elimino `/opt/apps/main-site` ni los volúmenes de Caddy.

## Repositorios y archivos locales

Uso `./sync-repos.sh "mensaje"` para sincronizar cambios ya revisados en los tres repositorios. Antes reviso todos los diffs, porque el script incluye los cambios pendientes, crea commits y hace push. Mantengo `init-projects.sh` y `.bat` para scaffolding; el arranque de estos clones sigue los pasos anteriores.

Dejo fuera de Git los `.env`, secretos, dependencias, builds, logs y dumps. Los [README de la API](felixsaucedo-api/README.md) y [de la UI](felixsaucedo-ui/README.md) describen sus contratos y configuración.
