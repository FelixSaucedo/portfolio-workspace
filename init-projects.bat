@echo off
setlocal EnableExtensions
cd /d "%~dp0" || exit /b 1
docker info >nul 2>&1
if errorlevel 1 (
  echo ERROR: Inicia Docker Desktop con contenedores Linux.
  exit /b 1
)
if exist felixsaucedo-api if not exist felixsaucedo-api\vendor\autoload.php (
  echo ERROR: API existente sin vendor/autoload.php. Restaura el proyecto antes de inicializar.
  exit /b 1
)
if exist felixsaucedo-ui if not exist felixsaucedo-ui\package.json (
  echo ERROR: UI existente sin package.json. Restaura el proyecto antes de inicializar.
  exit /b 1
)
if exist felixsaucedo-api goto apiExisting
docker run --rm -v "%cd%":/app -w /app composer:2 sh -ec "composer create-project --prefer-dist --no-interaction --no-install --no-scripts laravel/laravel felixsaucedo-api && cd felixsaucedo-api && composer config platform.php 8.4.0 && composer install --prefer-dist --no-interaction --no-scripts --ignore-platform-req=ext-*"
if errorlevel 1 goto failed
:apiExisting
if not exist felixsaucedo-api\artisan goto failed
if not exist felixsaucedo-api\vendor\autoload.php goto failed
docker run --rm -v "%cd%":/app -w /app/felixsaucedo-api php:8.4-cli-alpine sh -ec "php /app/scripts/configure-env.php && php /app/scripts/generate-key.php"
if errorlevel 1 goto failed
if exist felixsaucedo-ui goto uiExisting
docker run --rm -v "%cd%":/app -w /app node:22-alpine sh -ec "npm create vite@latest felixsaucedo-ui -- --template vue-ts"
if errorlevel 1 goto failed
:uiExisting
if not exist felixsaucedo-ui\package.json goto failed
xcopy /E /I /H /Y .docker-templates\felixsaucedo-api felixsaucedo-api >nul
if errorlevel 1 goto failed
xcopy /E /I /H /Y .docker-templates\felixsaucedo-ui felixsaucedo-ui >nul
if errorlevel 1 goto failed
docker run --rm -v "%cd%":/app -w /app/felixsaucedo-ui node:22-alpine sh -ec "npm uninstall postcss autoprefixer && npm install && npm install -D tailwindcss@latest @tailwindcss/vite@latest && node .docker/setup-tailwind.cjs"
if errorlevel 1 goto failed
echo Proyectos preparados. Ejecuta: docker compose up -d --build
exit /b 0
:failed
echo ERROR: La inicializacion fallo. Revisa el error anterior.
exit /b 1
