#!/bin/sh
set -eu

php /var/www/html/bin/init.php
exec php-fpm -F
