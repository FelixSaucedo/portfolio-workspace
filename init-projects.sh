#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
trap 'echo "ERROR: La inicializacion fallo en la linea $LINENO." >&2' ERR

if ! docker info >/dev/null 2>&1; then
  echo 'ERROR: Inicia Docker con contenedores Linux y soporte WSL2.' >&2
  exit 1
fi
container_user="$(id -u):$(id -g)"

for project in felixsaucedo-api felixsaucedo-ui; do
  marker=vendor/autoload.php
  [[ "$project" == felixsaucedo-ui ]] && marker=package.json
  if [[ -d "$project" && ! -f "$project/$marker" ]]; then
    echo "Limpiando $project incompleto: falta $marker."
    docker run --rm --user 0:0 -v "$PWD":/app -w /app \
      composer:2 sh -ec 'rm -rf -- "/app/$1"' sh "$project"
  fi
done

if [[ ! -d felixsaucedo-api ]]; then
  docker run --rm --user "$container_user" \
    -e COMPOSER_HOME=/tmp/composer -v "$PWD":/app -w /app \
    composer:2 sh -ec '
      composer create-project --prefer-dist --no-interaction --no-install --no-scripts laravel/laravel felixsaucedo-api
      cd felixsaucedo-api
      composer config platform.php 8.4.0
      composer install --prefer-dist --no-interaction --no-scripts --ignore-platform-req=ext-*
    '
fi

if [[ ! -f felixsaucedo-api/artisan || ! -f felixsaucedo-api/vendor/autoload.php ]]; then
  echo 'ERROR: Laravel no tiene artisan o vendor/autoload.php.' >&2
  exit 1
fi

docker run --rm --user "$container_user" -v "$PWD":/app \
  -w /app/felixsaucedo-api php:8.4-cli-alpine sh -ec '
    php /app/scripts/configure-env.php
    php /app/scripts/generate-key.php
  '

if [[ ! -d felixsaucedo-ui ]]; then
  docker run --rm --user "$container_user" -e npm_config_cache=/tmp/npm \
    -v "$PWD":/app -w /app node:22-alpine \
    sh -ec 'npm create vite@latest felixsaucedo-ui -- --template vue-ts'
fi
if [[ ! -f felixsaucedo-ui/package.json ]]; then
  echo 'ERROR: felixsaucedo-ui no contiene package.json.' >&2
  exit 1
fi

# Incluye .docker, .dockerignore y otros archivos ocultos.
cp -R .docker-templates/felixsaucedo-api/. felixsaucedo-api/
cp -R .docker-templates/felixsaucedo-ui/. felixsaucedo-ui/

docker run --rm --user "$container_user" -e npm_config_cache=/tmp/npm \
  -v "$PWD":/app -w /app/felixsaucedo-ui node:22-alpine sh -ec '
    npm uninstall postcss autoprefixer
    npm install
    npm install -D tailwindcss@latest @tailwindcss/vite@latest
    node .docker/setup-tailwind.cjs
  '

echo 'Proyectos preparados. Ejecuta: docker compose up -d --build'
