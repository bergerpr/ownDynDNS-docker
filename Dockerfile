ARG ALPINE_VERSION=latest

# --- Stage 1: fetch ownDynDNS ----------------------------------------------------
# The application is fetched at build time, never on container start: an image
# always contains exactly one code version, and a start needs no network.
#
# OWNDYNDNS_REF defaults to master, so every build ships the newest upstream
# state. It also takes a tag or a commit hash to pin a version.
#
# ADD with a git URL (not RUN git clone) on purpose: BuildKit checks the remote
# ref on every build and reuses the cache only while the commit is unchanged. A
# cached "RUN git clone" would silently keep shipping an old upstream state.
FROM alpine:${ALPINE_VERSION} AS source
ARG OWNDYNDNS_REPO=https://github.com/fernwerker/ownDynDNS.git
ARG OWNDYNDNS_REF=master
ADD --keep-git-dir=true ${OWNDYNDNS_REPO}#${OWNDYNDNS_REF} /src
RUN apk add --no-cache git \
    && mkdir /out \
    && git -C /src rev-parse HEAD > /out/REVISION \
    && cp /src/update.php /out/ \
    && cp -r /src/src /out/

# --- Stage 2: runtime ------------------------------------------------------------
FROM alpine:${ALPINE_VERSION}
LABEL maintainer="support.docker@kehrwoche.eu"

# Runtime packages. git and the openssl CLI are no longer needed (the code is
# fetched in the build stage). bash and curl stay for compatibility: existing
# deployments use them in healthchecks and `docker exec`.
RUN apk upgrade --no-cache \
    && apk add --no-cache \
        bash \
        curl \
        apache2 \
        php85-apache2 \
        ca-certificates \
        php85 \
        php85-soap \
        php85-mbstring \
        php85-curl \
        php85-json \
        php85-simplexml \
        php85-openssl \
        tzdata \
    && ln -sf /usr/bin/php85 /usr/bin/php

# Apache: document root, modules, error log to stderr. The default access log is
# replaced in conf.d/owndyndns.conf, because it would record the credentials that
# routers send in the query string.
RUN mkdir -p /run/apache2 \
    && sed -i "s/#LoadModule\ rewrite_module/LoadModule\ rewrite_module/" /etc/apache2/httpd.conf \
    && sed -i "s/#LoadModule\ deflate_module/LoadModule\ deflate_module/" /etc/apache2/httpd.conf \
    && sed -i "s#^DocumentRoot \".*#DocumentRoot \"/app/public\"#g" /etc/apache2/httpd.conf \
    && sed -i "s#/var/www/localhost/htdocs#/app/public#" /etc/apache2/httpd.conf \
    && sed -i -r 's@Errorlog .*@Errorlog /dev/stderr@i' /etc/apache2/httpd.conf \
    && sed -i -r 's@^([[:space:]]*)CustomLog @\1#CustomLog @' /etc/apache2/httpd.conf \
    && sed -i -r 's@^ServerTokens .*@ServerTokens Prod@' /etc/apache2/httpd.conf \
    && sed -i -r 's@^ServerSignature .*@ServerSignature Off@' /etc/apache2/httpd.conf
COPY apache/owndyndns.conf /etc/apache2/conf.d/owndyndns.conf

# PHP hardening defaults. Each of them can still be overridden by the PHP_*
# environment variables handled in start.sh.
RUN sed -i -r 's@^;?[[:space:]]*expose_php[[:space:]]*=.*@expose_php = Off@' /etc/php85/php.ini \
    && sed -i -r 's@^;?[[:space:]]*open_basedir[[:space:]]*=.*@open_basedir = /app:/tmp@' /etc/php85/php.ini \
    && sed -i -r 's@^;?[[:space:]]*disable_functions[[:space:]]*=.*@disable_functions = exec,passthru,shell_exec,system,proc_open,popen,pcntl_exec@' /etc/php85/php.ini

# Layout:
#   /app/owndyndns  application code + .env  (root-owned, NOT web-served)
#   /app/public     document root, only a wrapper that includes the application
#   /app/data       log.json, the only place the web server may write to
COPY --from=source /out/ /app/owndyndns/
# /app/owndyndns/REVISION holds the upstream commit this image was built from;
# start.sh prints it. The CI build may also pass it as a label, e.g.
# --label org.opencontainers.image.revision=<sha>.
COPY public/update.php /app/public/update.php
COPY public/update.php /bootstrap/update.php
RUN mkdir -p /app/data /bootstrap \
    && chown -R root:root /app/owndyndns /app/public \
    && find /app/owndyndns /app/public -type d -exec chmod 755 {} + \
    && find /app/owndyndns /app/public -type f -exec chmod 644 {} + \
    && chown apache:apache /app/data \
    && chmod 750 /app/data

# Keep a pristine copy of the base configuration. start.sh rebuilds .env from it
# on every start, so a container restart cannot append the credentials twice.
# awk normalises line endings and guarantees the trailing newline the appends need.
COPY config/.env /bootstrap/env.dist
RUN sed 's/\r$//' /bootstrap/env.dist | awk '{print}' > /bootstrap/env.base \
    && rm /bootstrap/env.dist

COPY start.sh /bootstrap/
RUN chmod 755 /bootstrap/start.sh

EXPOSE 80
ENTRYPOINT ["/bootstrap/start.sh"]
