#!/bin/sh
set -eu

php /var/www/html/vendor/bin/phinx migrate -c /var/www/html/phinx.php -e development
php /var/www/html/bin/init.php
exec php-fpm -F
