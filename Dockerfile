FROM alpine:latest
LABEL maintainer="seji@tihoda.de"

# Add basics first
RUN apk update && apk upgrade
RUN apk add \
    bash \
    apache2 \
    openssl \
    php82-apache2 \
    curl \
    ca-certificates \
    git \
    php82 \
    php82-soap \
    php82-mbstring \
    php82-curl \
    php82-json \
    php82-simplexml \
    php82-openssl \
    tzdata

RUN cp /usr/bin/php82 /usr/bin/php \
    && rm -f /var/cache/apk/*

# Add apache to run and configure
RUN mkdir -p /run/apache2 \
    && sed -i "s/#LoadModule\ rewrite_module/LoadModule\ rewrite_module/" /etc/apache2/httpd.conf \
    && sed -i "s/#LoadModule\ session_module/LoadModule\ session_module/" /etc/apache2/httpd.conf \
    && sed -i "s/#LoadModule\ session_cookie_module/LoadModule\ session_cookie_module/" /etc/apache2/httpd.conf \
    && sed -i "s/#LoadModule\ session_crypto_module/LoadModule\ session_crypto_module/" /etc/apache2/httpd.conf \
    && sed -i "s/#LoadModule\ deflate_module/LoadModule\ deflate_module/" /etc/apache2/httpd.conf \
    && sed -i "s#^DocumentRoot \".*#DocumentRoot \"/app/public\"#g" /etc/apache2/httpd.conf \
    && sed -i "s#/var/www/localhost/htdocs#/app/public#" /etc/apache2/httpd.conf \
    && sed -i -r 's@Errorlog .*@Errorlog /dev/stderr@i' /etc/apache2/httpd.conf \
    && printf "\n<Directory \"/app/public\">\n\tAllowOverride All\n</Directory>\n" >> /etc/apache2/httpd.conf

RUN mkdir /tmp/ownDynDNS \
    && mkdir -p /app/public \
    && chown -R apache:apache /app \
    && chmod -R 755 /app \
    && mkdir bootstrap
COPY ./config/. /app/public

ADD start.sh /bootstrap/
RUN chmod +x /bootstrap/start.sh

EXPOSE 80
ENTRYPOINT ["/bootstrap/start.sh"]