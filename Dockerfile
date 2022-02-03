#
# Docker with Sendy Email Campaign Marketing
#
# Build:
# $ docker build -t sendy:latest --target sendy -f ./Dockerfile .
#
# Build w/ XDEBUG installed
# $ docker build -t sendy:debug-latest --target debug -f ./Dockerfile .
#
# Run:
# $ docker run --rm -d --env-file sendy.env sendy:latest

FROM php:7.4.8-apache as sendy

RUN apt -qq update && apt -qq upgrade -y \
  # Install unzip cron
  && apt -qq install -y unzip cron  \
  # Install php extension gettext
  # Install php extension mysqli
  && docker-php-ext-install calendar gettext mysqli \
  # Remove unused packages
  && apt autoremove -y 

# Install Sendy
RUN mv /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini \
  ## Tweak PHP ini
  && sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /usr/local/etc/php/php.ini \
  && sed -i 's/max_execution_time = 30/max_execution_time = 120/g' /usr/local/etc/php/php.ini \
  && sed -i 's/memory_limit = 128M/memory_limit = 512M/g' /usr/local/etc/php/php.ini \
  && sed -i 's/post_max_size = 8M/post_max_size = 1024M/g' /usr/local/etc/php/php.ini \
  && sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 512M/g' /usr/local/etc/php/php.ini \
  && sed -i 's/max_input_time = 60/max_input_time = 120/g' /usr/local/etc/php/php.ini \
  && sed -i 's/max_input_vars = 1000/max_input_vars = 5000/g' /usr/local/etc/php/php.ini \
  && sed -i 's/short_open_tag = Off/short_open_tag = On/g' /usr/local/etc/php/php.ini \
  && sed -i 's/zlib.output_compression = Off/zlib.output_compression = On/g' /usr/local/etc/php/php.ini \
  && sed -i 's/;opcache.enable=1/opcache.enable=1/g' /usr/local/etc/php/php.ini \
  && sed -i 's/;opcache.save_comments=1/opcache.save_comments=1/g' /usr/local/etc/php/php.ini \
  && sed -i 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 7200/g' /usr/local/etc/php/php.ini \
  && sed -i 's/;date.timezone.*/date.timezone = UTC/' /usr/local/etc/php/php.ini \
  # Set server name
  && echo "\nServerName \${SENDY_FQDN}" > /etc/apache2/conf-available/serverName.conf \
  # Ensure X-Powered-By is always removed regardless of php.ini or other settings.
  && printf "\n\n# Ensure X-Powered-By is always removed regardless of php.ini or other settings.\n\
  Header always unset \"X-Powered-By\"\n\
  Header unset \"X-Powered-By\"\n" >> /var/www/html/.htaccess \
  && printf "[PHP]\nerror_reporting = E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED\n" > /usr/local/etc/php/conf.d/error_reporting.ini

# Apache config
RUN a2enconf serverName

# Apache modules
RUN a2enmod rewrite headers

# Copy hello-cron file to the cron.d directory
COPY cron /etc/cron.d/cron
# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/cron \
  # Apply cron job
  && crontab /etc/cron.d/cron \
  # Create the log file to be able to run tail
  && touch /var/log/cron.log

COPY ./docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]

#######################
# XDEBUG Installation
#######################
FROM sendy as debug
# Install xdebug extension
RUN pecl channel-update pecl.php.net \
  && pecl install xdebug \
  && docker-php-ext-enable xdebug \
  && rm -rf /tmp/pear 
