FROM php:8.4-fpm-alpine3.23

RUN apk add --no-cache oniguruma \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS oniguruma-dev \
    && docker-php-ext-install mbstring pdo_mysql \
    && apk del .build-deps

WORKDIR /var/www/html
COPY . /var/www/html
RUN chmod +x /var/www/html/entrypoint.sh

EXPOSE 9000
ENTRYPOINT ["/var/www/html/entrypoint.sh"]
