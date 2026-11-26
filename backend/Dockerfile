FROM php:8.4-fpm-alpine3.23

RUN apk add --no-cache oniguruma \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS oniguruma-dev \
    && docker-php-ext-install mbstring pdo_mysql \
    && apk del .build-deps

WORKDIR /var/www/html
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY backend/composer.json backend/composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --classmap-authoritative
COPY backend/ /var/www/html/
COPY config.php /var/www/config.php
RUN chmod +x /var/www/html/entrypoint.sh

EXPOSE 9000
ENTRYPOINT ["/var/www/html/entrypoint.sh"]
