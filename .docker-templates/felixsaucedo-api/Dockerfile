FROM php:8.4-fpm-alpine AS php-base
RUN apk add --no-cache libzip oniguruma libxml2 icu-libs \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS libzip-dev oniguruma-dev libxml2-dev icu-dev \
    && docker-php-ext-install -j2 pdo_mysql mbstring xml bcmath zip opcache intl \
    && apk del .build-deps
WORKDIR /var/www/html
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY .docker/entrypoint.sh /usr/local/bin/app-entrypoint
RUN chmod +x /usr/local/bin/app-entrypoint
ENV APP_ENV=local
ENTRYPOINT ["app-entrypoint"]
CMD ["php-fpm"]
