# Deployment doesn't work on Alpine
FROM php:7.2-cli AS deployer
# DO NOT FORGET TO UPDATE "tags" FILE
ENV OSTICKET_VERSION=1.11
RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends git-core unzip \
    && rm -rf /var/lib/apt/lists/*
RUN set -x \
    && git clone -b v${OSTICKET_VERSION} --depth 1 https://github.com/osTicket/osTicket.git \
    && cd osTicket \
    # Deploy sources
    && php manage.php deploy -sv /install/usr/local/src/osticket \
    && chmod 755 /install/usr/local/src/osticket \
    # Hard link the sources to the public directory
    && mkdir -p /install/var/www \
    && cp -al /install/usr/local/src/osticket /install/var/www/html \
    # Hide setup
    && rm -r /install/var/www/html/setup \
    # Clean up
    && cd .. \
    && rm -rf osTicket
RUN set -ex; \
    for lang in ar az bg ca cs da de el es_ES et fr hr hu it ja ko lt mk mn nl no fa pl pt_PT \
        pt_BR sk sl sr_CS fi sv_SE ro ru vi th tr uk zh_CN zh_TW; do \
        curl -so /install/var/www/html/include/i18n/${lang}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/lang/${lang}.phar; \
    done
RUN set -ex; \
    git clone --depth 1 https://github.com/devinsolutions/osTicket-plugins.git; \
    cd osTicket-plugins; \
    php make.php hydrate; \
    for plugin in $(find * -maxdepth 0 -type d ! -path doc ! -path lib); do \
        php -dphar.readonly=0 make.php build ${plugin}; \
        mv ${plugin}.phar /install/var/www/html/include/plugins; \
    done; \
    cd ..; \
    rm -rf osTicket-plugins
RUN set -ex; \
    git clone --depth 1 https://github.com/devinsolutions/osTicket-slack-plugin.git; \
    cd osTicket-slack-plugin; \
    mv slack /install/var/www/html/include/plugins; \
    cd ..; \
    rm -rf osTicket-slack-plugin
COPY files /install

FROM php:7.2-fpm-alpine3.9
RUN set -x \
    # Runtime dependencies
    && apk add --no-cache --update \
        ca-certificates \
        c-client \
        curl \
        icu \
        libintl \
        libpng \
        libxml2 \
        msmtp \
        nginx \
        openldap \
        runit \
    # Build dependencies
    && apk add --no-cache --virtual .build-deps \
        autoconf \
        curl-dev \
        g++ \
        gettext-dev \
        icu-dev \
        imap-dev \
        libpng-dev \
        libxml2-dev \
        make \
        openldap-dev \
        pcre-dev \
    # Install PHP extensions
    && docker-php-ext-configure imap --with-imap-ssl \
    && docker-php-ext-install \
        curl \
        gd \
        gettext \
        imap \
        intl \
        ldap \
        mbstring \
        mysqli \
        opcache \
        sockets \
        xml \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    # Create msmtp log
    && touch /var/log/msmtp.log \
    && chown www-data:www-data /var/log/msmtp.log \
    # File upload permissions
    && chown nginx:www-data /var/tmp/nginx \
    && chmod g+rx /var/tmp/nginx \
    # Create data dir
    && mkdir /var/lib/osticket \
    # Clean up
    && apk del .build-deps \
    && rm -rf /tmp/pear /var/cache/apk/*
COPY --from=deployer /install /
CMD ["start"]
EXPOSE 80
HEALTHCHECK CMD curl -fIsS http://localhost/ || exit 1
