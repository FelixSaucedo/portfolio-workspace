#!/bin/sh
set -eu
mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs storage/app/public bootstrap/cache
if [ "${APP_ENV:-local}" != production ]; then
    composer install --prefer-dist --no-interaction --no-progress
    php artisan config:clear
else
    php artisan config:cache
fi
chown -R www-data:www-data storage bootstrap/cache
chmod -R ug+rwX storage bootstrap/cache
exec docker-php-entrypoint "$@"
