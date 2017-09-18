#!/bin/bash

# NextCloud Optimization Script
# with PHP Opcache and Redis Memcache
# Important: Do not run until the setup wizard in your browser is complete (has initialized the config.php file).
# Author: Autoize (autoize.com)

upload_max_filesize=4G # Largest filesize users may upload through the web interface
post_max_size=4G # Same as above
memory_limit=512M # Amount of memory NextCloud may consume
datapath='/cloudData' # Path where user data is stored

# DO NOT EDIT BELOW THIS LINE

ocpath='/var/www/nextcloud' # Path where NextCloud is installed

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Set mod_rewrite base directory to enable pretty URLs
sed -i '$i'"'"'htaccess.RewriteBase'"'"' => '"'"'/nextcloud'"'"','''  ${ocpath}/config/config.php
chown www-data:www-data ${ocpath}/.htaccess
cd ${ocpath}
sudo -u www-data ./occ maintenance:update:htaccess
chown root:www-data ${ocpath}/.htaccess

# Enable PHP Opcache
printf "opcache.enable=1\nopcache.enable_cli=1\nopcache.interned_strings_buffer=8\nopcache.max_accelerated_files=10000\nopcache.memory_consumption=128\nopcache.save_comments=1\nopcache.revalidate_freq=1" >> /etc/php/7.0/fpm/conf.d/10-opcache.ini

# Enable Redis memory caching
sed -i '$i'"'"'memcache.local'"'"' => '"'"'\\OC\\Memcache\\Redis'"'"','''  ${ocpath}/config/config.php
sed -i '$i'"'"'memcache.locking'"'"' => '"'"'\\OC\\Memcache\\Redis'"'"','''  ${ocpath}/config/config.php
sed -i '$i'"'"'redis'"'"' => array('"\n""'"'host'"'"' => '"'"'localhost'"'"','"\n""'"'port'"'"' => 6379,'"\n"'),'''  ${ocpath}/config/config.php

# Change the upload cache directory
# Makes it easier to exclude cache from rsync-style backups
sed -i '$i'"'"'cache_path'"'"' => '"'"${datapath}'/cache'"'"','''  ${ocpath}/config/config.php

# Change the PHP upload and memory limits

for key in upload_max_filesize post_max_size memory_limit
do
sed -i "s/^\($key\).*/\1=$(eval echo \${$key})/" ${ocpath}/.user.ini
done

# Reboot server to apply settings

printf "\n\nOptimization complete.\nRebooting server now\n\n"
sleep 5
reboot
