FROM php:7.3-fpm-alpine3.10
RUN set -ex; \
    \
    # Runtime dependencies
    apk add --no-cache \
        ca-certificates \
        c-client \
        curl \
        icu \
        libintl \
        libpng \
        libzip \
        msmtp \
        nginx \
        openldap \
        runit \
    ; \
    \
    # Build dependencies
    apk add --no-cache --virtual .build-deps \
        ${PHPIZE_DEPS} \
        gettext-dev \
        icu-dev \
        imap-dev \
        libpng-dev \
        libzip-dev \
        openldap-dev \
    ; \
    \
    # Install PHP extensions
    docker-php-ext-configure imap --with-imap-ssl; \
    docker-php-ext-install -j "$(nproc)" \
        gd \
        gettext \
        imap \
        intl \
        ldap \
        mysqli \
        sockets \
        zip \
    ; \
    pecl install apcu; \
    docker-php-ext-enable \
        apcu \
        opcache \
    ; \
    \
    # Create msmtp log
    touch /var/log/msmtp.log; \
    chown www-data:www-data /var/log/msmtp.log; \
    \
    # File upload permissions
    chown nginx:www-data /var/tmp/nginx; \
    chmod g+rx /var/tmp/nginx; \
    \
    # Create data dir
    mkdir /var/lib/osticket; \
    \
    # Clean up
    apk del .build-deps; \
    rm -rf /tmp/pear /var/cache/apk/*
# DO NOT FORGET TO UPDATE "tags" FILE
ENV OSTICKET_VERSION=1.14.1 \
    OSTICKET_SHA256SUM=fa751b78fe84212376ab25e867b93c8a45d426917ae7d946f4be216d9b23505f
RUN set -ex; \
    \
    apk add --no-cache --virtual .build-deps \
        git \
    ; \
    \
    wget -q -O osTicket.zip https://github.com/osTicket/osTicket/releases/download/\
v${OSTICKET_VERSION}/osTicket-v${OSTICKET_VERSION}.zip; \
    echo "${OSTICKET_SHA256SUM}  osTicket.zip" | sha256sum -c; \
    unzip osTicket.zip 'upload/*'; \
    rm osTicket.zip; \
    mkdir /usr/local/src; \
    mv upload /usr/local/src/osticket; \
    # Hard link the sources to the public directory
    cp -al /usr/local/src/osticket/. /var/www/html; \
    # Hide setup
    rm -r /var/www/html/setup; \
    \
    for lang in ar az bg ca cs da de el es_ES et fr hr hu it ja ko lt mk mn nl no fa pl pt_PT \
        pt_BR sk sl sr_CS fi sv_SE ro ru vi th tr uk zh_CN zh_TW; do \
        curl -so /var/www/html/include/i18n/${lang}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/lang/${lang}.phar; \
    done; \
    \
    git clone --depth 1 https://github.com/devinsolutions/osTicket-plugins.git; \
    cd osTicket-plugins; \
    php make.php hydrate; \
    for plugin in $(find * -maxdepth 0 -type d ! -path doc ! -path lib); do \
        mv ${plugin} /var/www/html/include/plugins; \
    done; \
    cd ..; \
    rm -rf osTicket-plugins; \
    \
    git clone --depth 1 https://github.com/devinsolutions/osTicket-slack-plugin.git; \
    cd osTicket-slack-plugin; \
    mv slack /var/www/html/include/plugins; \
    cd ..; \
    rm -rf osTicket-slack-plugin; \
    \
    apk del .build-deps; \
    rm -rf /root/.composer /var/cache/apk/*
COPY files /
CMD ["start"]
STOPSIGNAL SIGTERM
EXPOSE 80
HEALTHCHECK CMD curl -fIsS http://localhost/ || exit 1
