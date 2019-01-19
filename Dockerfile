# Deployment doesn't work on Alpine
FROM php:7.0-cli AS deployer
ENV OSTICKET_VERSION=1.10.4
RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends git-core
RUN set -x \
    && git clone -b v${OSTICKET_VERSION} --depth 1 https://github.com/osTicket/osTicket.git \
    && cd osTicket \
    && php manage.php deploy -sv /data/upload \
    # www-data is uid:gid 82:82 in php:7.0-fpm-alpine
    && chown -R 82:82 /data/upload \
    # Hide setup
    && mv /data/upload/setup /data/upload/setup_hidden \
    && chown -R root:root /data/upload/setup_hidden \
    && chmod -R go= /data/upload/setup_hidden
RUN set -ex; \
    for lang in ar az bg ca cs da de el es_ES et fr hr hu it ja ko lt mk mn nl no fa pl pt_PT \
        pt_BR sk sl sr_CS fi sv_SE ro ru vi th tr uk zh_CN zh_TW; do \
        curl -so /data/upload/include/i18n/${lang}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/lang/${lang}.phar; \
    done; \
    mv /data/upload/include/i18n /data/upload/include/i18n.dist
RUN set -ex; \
    git clone --depth 1 https://github.com/devinsolutions/osTicket-plugins.git; \
    cd osTicket-plugins; \
    php make.php hydrate; \
    for plugin in $(find * -maxdepth 0 -type d ! -path doc ! -path lib); do \
        php -dphar.readonly=0 make.php build ${plugin}; \
        mv ${plugin}.phar /data/upload/include/plugins; \
    done
RUN set -ex; \
    git clone --depth 1 https://github.com/devinsolutions/osTicket-slack-plugin.git; \
    cd osTicket-slack-plugin; \
    mv slack /data/upload/include/plugins

FROM php:7.0-fpm-alpine
# environment for osticket
ENV HOME=/data
# setup workdir
WORKDIR /data
RUN set -x && \
    # requirements and PHP extensions
    apk add --no-cache --update \
        wget \
        msmtp \
        ca-certificates \
        supervisor \
        nginx \
        libpng \
        c-client \
        openldap \
        libintl \
        libxml2 \
        icu \
        openssl && \
    apk add --no-cache --virtual .build-deps \
        imap-dev \
        libpng-dev \
        curl-dev \
        openldap-dev \
        gettext-dev \
        libxml2-dev \
        icu-dev \
        autoconf \
        g++ \
        make \
        pcre-dev && \
    docker-php-ext-install gd curl ldap mysqli sockets gettext mbstring xml intl opcache && \
    docker-php-ext-configure imap --with-imap-ssl && \
    docker-php-ext-install imap && \
    pecl install apcu && docker-php-ext-enable apcu && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* && \
    # Create msmtp log
    touch /var/log/msmtp.log && \
    chown www-data:www-data /var/log/msmtp.log && \
    # File upload permissions
    chown nginx:www-data /var/tmp/nginx && chmod g+rx /var/tmp/nginx
COPY --from=deployer /data/upload upload
COPY files/ /
VOLUME ["/data/upload/include/plugins","/data/upload/include/i18n","/var/log/nginx"]
EXPOSE 80
CMD ["/data/bin/start.sh"]
