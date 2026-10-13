# portfolio-workspace

Mi sitio personal reúne mi experiencia, proyectos y CV, con contenido en español e inglés. En este repositorio guardo la configuración de Docker y los scripts que uso para trabajar con la API y la interfaz.

El sitio está disponible en [felixsaucedo.com](https://felixsaucedo.com).

## Organización

Organizo el proyecto en tres repositorios: uno para la API, otro para la interfaz y este para ejecutarlos juntos.

| Repositorio | Responsabilidad |
| --- | --- |
| [portfolio-workspace](https://github.com/FelixSaucedo/portfolio-workspace) | Docker Compose para ejecutar los servicios y Nginx para dirigir las solicitudes. |
| [felixsaucedo-api](https://github.com/FelixSaucedo/felixsaucedo-api) | Laravel 13 y PHP 8.4 para gestionar el contenido y los mensajes de contacto. |
| [felixsaucedo-ui](https://github.com/FelixSaucedo/felixsaucedo-ui) | Vue 3.5 y TypeScript para la interfaz, Vite 8 para trabajar con ella y preparar su publicación, y Tailwind CSS 4 para los estilos. |

Descargo la API y la UI dentro de esta carpeta, pero cada una mantiene su propio historial en Git. Si cambio los datos que entrega la API, también reviso cómo los usa la interfaz.

## Arquitectura

Uso Nginx para que la interfaz y la API compartan el mismo dominio. Nginx recibe las solicitudes y las dirige a la aplicación correspondiente, lo que simplifica la comunicación desde el navegador.

Laravel gestiona el contenido y los contactos, y MySQL guarda los datos. Primero registro cada mensaje y después envío los correos en segundo plano, para que quien escribe no tenga que esperar al envío.

Mientras trabajo en la interfaz, Vite muestra los cambios en el navegador sin que tenga que actualizar la página manualmente. Para publicar el sitio, preparo las imágenes de Docker con la API y la versión compilada de la interfaz.

## Servicios y función

Docker Compose ejecuta los servicios que necesita el sitio:

| Servicio | Función |
| --- | --- |
| `gateway` | Nginx recibe las solicitudes y las dirige a la interfaz o a la API. |
| `api` | PHP-FPM ejecuta Laravel, que gestiona el contenido y los contactos. |
| `ui` | Vite permite ver los cambios mientras trabajo; en producción, Nginx sirve la interfaz compilada. |
| `db` | MySQL 8.4 guarda los datos en un volumen de Docker, para conservarlos al actualizar los contenedores. |
| `contact-worker` | Envía los correos pendientes de la cola `contacts`. |
| `contact-scheduler` | Revisa cada minuto si hay contactos cuyo envío de correos quedó pendiente. |

## Desarrollo local

Trabajo con PHP, Composer y Node dentro de Docker. Así uso las mismas versiones sin tener que instalar cada herramienta por separado en mi equipo. Para ejecutar el proyecto necesito Git y Docker Compose con contenedores Linux.

```bash
git clone https://github.com/FelixSaucedo/portfolio-workspace.git
cd portfolio-workspace
git clone https://github.com/FelixSaucedo/felixsaucedo-api.git
git clone https://github.com/FelixSaucedo/felixsaucedo-ui.git
cp felixsaucedo-api/.env.example felixsaucedo-api/.env
```

Antes de iniciar los servicios, completo la configuración del correo y del administrador en el `.env` de la API. Su archivo de ejemplo y su README indican qué valores necesito.

```bash
docker compose up -d --build db api ui
docker compose exec api php artisan key:generate --no-interaction
docker compose exec api php artisan migrate --no-interaction
docker compose exec api php artisan db:seed --no-interaction
docker compose up -d
```

Después de estos pasos puedo abrir el sitio en `http://localhost`. Genero la clave de Laravel solo en la primera instalación y la conservo cuando actualizo el proyecto.

## Validación

Uso estos comandos para revisar la configuración de Docker, ejecutar las pruebas y comprobar que la interfaz compila:

```bash
docker compose config --quiet
docker compose exec api php artisan test --compact
docker compose exec ui npm test
docker compose exec ui npm run build
```

Las pruebas de Laravel usan una base de datos separada. Algunas pruebas de la interfaz consultan la API local para comprobar que los datos coinciden con lo esperado, por eso dejo los servicios activos al ejecutarlas.

## Despliegue

Publico mi portafolio en AWS con Docker. Caddy se encarga de HTTPS para que el sitio se pueda abrir mediante una conexión cifrada, y Nginx dirige las solicitudes hacia la interfaz o la API. Uso configuraciones distintas para trabajar en mi equipo y para publicar el sitio.

## Trabajo con los repositorios

Uso `sync-repos.sh` para guardar los cambios en commits y subirlos a GitHub en los tres repositorios. Como el script incluye todos los cambios pendientes, primero reviso qué archivos modifiqué en cada uno.

Dejo fuera de Git los archivos `.env`, las credenciales, las dependencias instaladas y los archivos generados al compilar. Los [README de la API](https://github.com/FelixSaucedo/felixsaucedo-api#readme) y [de la UI](https://github.com/FelixSaucedo/felixsaucedo-ui#readme) explican cómo trabajar con cada aplicación.
