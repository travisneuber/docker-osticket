FROM php:8.0-fpm-buster
RUN set -ex; \
    \
    export CFLAGS="-Os"; \
    export CPPFLAGS="${CFLAGS}"; \
    export LDFLAGS="-Wl,--strip-all";
RUN apt update -y
# Runtime dependencies
RUN apt install -y \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    gnupg2 \
    wget \
    curl \
    zip \
    unzip \
    autoconf \
    dpkg-dev \
    file \
    g++ \
    gcc \
    libc-dev \
    make \
    pkg-config \
    re2c \
    xz-utils \
    nginx \
    msmtp \
    runit \
    cron \
;
# Build dependencies
RUN apt install -y \
    ${PHPIZE_DEPS} \
    libc-client-dev \
    libkrb5-dev \
    zlib1g-dev \
    libpng-dev \
    libicu-dev \
    libldb-dev \
    libldap2-dev \
    libzip-dev \
    dos2unix \
;
# Install PHP extensions
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/; 
RUN docker-php-ext-install -j "$(nproc)" \
    gd \
    gettext \
    imap \
    intl \
    ldap \
    mysqli \
    sockets \
    zip \
;
RUN pecl install apcu; 
RUN docker-php-ext-enable \
    apcu \
    opcache \
;
# Create msmtp log
RUN touch /var/log/msmtp.log; 
RUN chown www-data:www-data /var/log/msmtp.log; 
# Create data dir
RUN mkdir /var/lib/osticket;
# Clean up
RUN rm -rf /var/lib/apt/lists/*
# DO NOT FORGET TO CHECK THE LANGUAGE PACK DOWNLOAD URL BELOW
# DO NOT FORGET TO UPDATE "image-version" FILE
ENV OSTICKET_VERSION=1.17
RUN set -ex; \
    \
    wget -q -O osTicket.zip https://github.com/osTicket/osTicket/releases/download/\
v${OSTICKET_VERSION}/osTicket-v${OSTICKET_VERSION}.zip; \
    unzip osTicket.zip 'upload/*'; \
    rm osTicket.zip; \
    # mkdir /usr/local/src; \
    mv upload /usr/local/src/osticket; \
    # Hard link the sources to the public directory
    cp -al /usr/local/src/osticket/. /var/www/html; \
    # Hide setup
    rm -r /var/www/html/setup;
RUN set -ex; \
    for lang in ar_EG ar_SA az bg bn bs ca cs da de el es_AR es_ES es_MX et eu fa fi fr gl he hi \
        hr hu id is it ja ka km ko lt lv mk mn ms nl no pl pt_BR pt_PT ro ru sk sl sq sr sr_CS \
        sv_SE sw th tr uk ur_IN ur_PK vi zh_CN zh_TW; do \
        # This URL is the same as what is used by the official osTicket Downloads page. This URL is
        # used even for minor versions >= 14.
        wget -q -O /var/www/html/include/i18n/${lang}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/lang/1.14.x/${lang}.phar; \
    done
ENV OSTICKET_PLUGINS_VERSION=1.17.x 
RUN set -ex; \
    \
    wget -q -O osTicket-plugins.tar.gz https://codeload.github.com/osTicket/osTicket-plugins/tar.gz/refs/heads/\
${OSTICKET_PLUGINS_VERSION}; \
    tar -xzf osTicket-plugins.tar.gz --one-top-level --strip-components 1; \
    rm osTicket-plugins.tar.gz; \
    \
    cd osTicket-plugins; \
    php make.php hydrate;
RUN cd osTicket-plugins; \
    find * -maxdepth 0 -type d ! -path doc ! -path lib -exec mv '{}' /var/www/html/include/plugins \;
RUN rm -r osTicket-plugins
RUN mkdir /temp-build
COPY root /temp-build
RUN cd /temp-build && find . -type f -print0 | xargs -0 dos2unix && \cp -r /temp-build/* / && rm -rf /temp-build
CMD ["start"]
STOPSIGNAL SIGTERM
EXPOSE 80
HEALTHCHECK CMD curl -fIsS http://localhost/ || exit 1
