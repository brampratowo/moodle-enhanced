FROM moodlehq/moodle-php-apache:8.3

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN mkdir -p /var/www/moodledata && chown -R www-data:www-data /var/www/moodledata

RUN { \
    echo "upload_max_filesize = 256M"; \
    echo "post_max_size = 256M"; \
    echo "memory_limit = 512M"; \
    echo "max_execution_time = 300"; \
    echo "max_input_vars = 5000"; \
  } > /usr/local/etc/php/conf.d/moodle.ini

WORKDIR /var/www/html
