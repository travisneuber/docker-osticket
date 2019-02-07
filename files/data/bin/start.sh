#!/bin/sh
# (C) Campbell Software Solutions 2015
set -e

# Automate installation
php /usr/local/src/osticket/setup/install.php
echo Applying configuration file security
chmod 644 /data/upload/include/ost-config.php

mkdir -p /run/nginx
chown -R www-data:www-data /run/nginx
chown -R www-data:www-data /var/lib/nginx
mkdir -p /var/log/php
chown -R www-data:www-data /var/log/php

exec runsvdir /etc/service
