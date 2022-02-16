FROM php:8.0-fpm-alpine3.15
RUN set -ex; \
    \
    export CFLAGS="-Os"; \
    export CPPFLAGS="${CFLAGS}"; \
    export LDFLAGS="-Wl,--strip-all"; \
    \
    # Runtime dependencies
    apk add --no-cache \
        c-client \
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
    # Create data dir
    mkdir /var/lib/osticket; \
    \
    # Clean up
    apk del .build-deps; \
    rm -rf /tmp/pear /var/cache/apk/*
# DO NOT FORGET TO UPDATE "image-version" FILE
ENV OSTICKET_VERSION=1.16.1 \
    OSTICKET_SHA256SUM=4cfb6a297b48f551b0988a7df72448fe7ec22ee38e4023fafc19ead41fb76b38
RUN set -ex; \
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
        wget -q -O /var/www/html/include/i18n/${lang}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/lang/${lang}.phar; \
    done
ENV OSTICKET_PLUGINS_VERSION=93d7d6d11670c7eac7a4e432dbc15f40375a70cf \
    OSTICKET_PLUGINS_SHA256SUM=0d4b60045be607d377a7d27a3d5143d5db36041f992c8924816604a81bb342d6
RUN set -ex; \
    \
    wget -q -O osTicket-plugins.tar.gz https://github.com/devinsolutions/osTicket-plugins/archive/\
${OSTICKET_PLUGINS_VERSION}.tar.gz; \
    echo "${OSTICKET_PLUGINS_SHA256SUM}  osTicket-plugins.tar.gz" | sha256sum -c; \
    tar -xzf osTicket-plugins.tar.gz --one-top-level --strip-components 1; \
    rm osTicket-plugins.tar.gz; \
    \
    cd osTicket-plugins; \
    php make.php hydrate; \
    find * -maxdepth 0 -type d ! -path doc ! -path lib -exec mv '{}' \
        /var/www/html/include/plugins +; \
    cd ..; \
    \
    rm -r osTicket-plugins /root/.composer
ENV OSTICKET_SLACK_VERSION=cd98e54fcadf1a5dd8e78b0a0380561c7ef29b02 \
    OSTICKET_SLACK_SHA256SUM=9cdead701fd1be91a64451dfaca98148b997dc4e5a0ff1a61965bffeebd65540
RUN set -ex; \
    \
    wget -q -O osTicket-slack-plugin.tar.gz https://github.com/devinsolutions/\
osTicket-slack-plugin/archive/${OSTICKET_SLACK_VERSION}.tar.gz; \
    echo "${OSTICKET_SLACK_SHA256SUM}  osTicket-slack-plugin.tar.gz" | sha256sum -c; \
    tar -xzf osTicket-slack-plugin.tar.gz -C /var/www/html/include/plugins --strip-components 1 \
        osTicket-slack-plugin-${OSTICKET_SLACK_VERSION}/slack; \
    rm osTicket-slack-plugin.tar.gz
COPY root /
CMD ["start"]
STOPSIGNAL SIGTERM
EXPOSE 80
HEALTHCHECK CMD curl -fIsS http://localhost/ || exit 1
