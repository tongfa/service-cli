FROM debian:wheezy

MAINTAINER Leonid Makarov <leonid.makarov@blinkreaction.com>

# Prevent services autoload (http://jpetazzo.github.io/2013/10/06/policy-rc-d-do-not-start-services-automatically/)
RUN echo '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

# Enabling additional repos
RUN sed -i 's/main/main contrib non-free/' /etc/apt/sources.list

# Basic packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes --no-install-recommends install \
    curl \
    wget \
    zip unzip \
    git \
    mysql-client \
    imagemagick \
    pv \
    openssh-client \
    rsync \
    ca-certificates \
    apt-transport-https \
    locales \
    mc \
    supervisor \
    sudo \
    procps \
    # Cleanup
    && DEBIAN_FRONTEND=noninteractive apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set timezone and locale
RUN dpkg-reconfigure locales && \
    locale-gen C.UTF-8 && \
    /usr/sbin/update-locale LANG=C.UTF-8
ENV LC_ALL C.UTF-8

RUN \
    # Create a non-root user with access to sudo and the default group set to 'users' (gid = 100)
    useradd -m -s /bin/bash -g users -G sudo -p docker docker && \
    echo 'docker ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    # Install gosu and give access to it for the users group. gosu will be used to run services as a different user.
    curl -sSL "https://github.com/tianon/gosu/releases/download/1.7/gosu-$(dpkg --print-architecture)" -o /usr/local/bin/gosu && \
    chown root:users /usr/local/bin/gosu && \
    chmod +sx /usr/local/bin/gosu

# Add Dotdeb PHP5.6 repo
RUN curl -sSL http://www.dotdeb.org/dotdeb.gpg | apt-key add - && \
    echo 'deb http://packages.dotdeb.org wheezy-php56 all' > /etc/apt/sources.list.d/dotdeb.list && \
    echo 'deb-src http://packages.dotdeb.org wheezy-php56 all' >> /etc/apt/sources.list.d/dotdeb.list

# PHP packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes --no-install-recommends install \
    php5-common \
    php5-cli \
    php-pear \
    php5-mysql \
    php5-imagick \
    php5-mcrypt \
    php5-curl \
    php5-gd \
    php5-sqlite \
    php5-json \
    php5-intl \
    php5-fpm \
    php5-memcache \
    php5-xdebug \
    # Cleanup
    && DEBIAN_FRONTEND=noninteractive apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

## PHP settings
RUN mkdir -p /var/www/docroot && \
    # PHP-FPM settings
    sed -i '/memory_limit = /c memory_limit = 256M' /etc/php5/fpm/php.ini && \
    sed -i '/max_execution_time = /c max_execution_time = 300' /etc/php5/fpm/php.ini && \
    sed -i '/upload_max_filesize = /c upload_max_filesize = 500M' /etc/php5/fpm/php.ini && \
    sed -i '/post_max_size = /c post_max_size = 500M' /etc/php5/fpm/php.ini && \
    sed -i '/error_log = php_errors.log/c error_log = \/dev\/stdout' /etc/php5/fpm/php.ini && \
    sed -i '/;always_populate_raw_post_data/c always_populate_raw_post_data = -1' /etc/php5/fpm/php.ini && \
    sed -i '/user = /c user = docker' /etc/php5/fpm/pool.d/www.conf && \
    sed -i '/listen = /c listen = 0.0.0.0:9000' /etc/php5/fpm/pool.d/www.conf && \
    sed -i '/listen.allowed_clients/c ;listen.allowed_clients =' /etc/php5/fpm/pool.d/www.conf && \
    sed -i '/;daemonize/c daemonize = no' /etc/php5/fpm/php-fpm.conf && \
    sed -i '/;catch_workers_output/c catch_workers_output = yes' /etc/php5/fpm/php-fpm.conf && \
    # PHP CLI settings
    sed -i '/memory_limit = /c memory_limit = 512M' /etc/php5/cli/php.ini && \
    sed -i '/max_execution_time = /c max_execution_time = 600' /etc/php5/cli/php.ini && \
    sed -i '/error_log = php_errors.log/c error_log = \/dev\/stdout' /etc/php5/cli/php.ini && \
    # PHP module settings
    echo 'opcache.memory_consumption=128' >> /etc/php5/mods-available/opcache.ini

COPY config/php5/xdebug.ini /etc/php5/mods-available/xdebug.ini

# Adding NodeJS repo (for up-to-date versions)
# This is a stripped down version of the official nodejs install script (https://deb.nodesource.com/setup_4.x)
RUN curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
    echo 'deb https://deb.nodesource.com/node_4.x wheezy main' > /etc/apt/sources.list.d/nodesource.list && \
    echo 'deb-src https://deb.nodesource.com/node_4.x wheezy main' >> /etc/apt/sources.list.d/nodesource.list

# Other language packages and dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes --no-install-recommends install \
    ruby1.9.1-full \
    rlwrap \
    build-essential \
    nodejs \
    # Cleanup
    && DEBIAN_FRONTEND=noninteractive apt-get clean &&\
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Bundler
RUN gem install bundler
# Home directory for bundle installs
ENV BUNDLE_PATH .bundler

# Grunt, Bower
RUN npm install -g grunt-cli bower

RUN \
    # Composer
    curl -sSL https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    # Drupal Console
    curl -sSL http://drupalconsole.com/installer | php && \
    mv console.phar /usr/local/bin/drupal
ENV PATH /home/docker/.composer/vendor/bin:$PATH

# All further RUN commands will run as the "docker" user
USER docker

RUN \
    # Drush 6,7 (default),8
    composer global require drush/drush:7.* && \
    mkdir /home/docker/drush6 && cd /home/docker/drush6 && composer require drush/drush:6.* && \
    mkdir /home/docker/drush8 && cd /home/docker/drush8 && composer require drush/drush:dev-master --prefer-dist && \
    echo "alias drush6='/home/docker/drush6/vendor/bin/drush'" >> /home/docker/.bashrc && \
    echo "alias drush7='/home/docker/.composer/vendor/bin/drush'" >> /home/docker/.bashrc && \
    echo "alias drush8='/home/docker/drush8/vendor/bin/drush'" >> /home/docker/.bashrc && \
    # Drush modules
    drush dl registry_rebuild && \
    # Drupal Coder (8.x) => matching version of PHP_CodeSniffer
    composer global require drupal/coder && \
    drush dl coder-8.x-2.3 --destination=/home/docker/.drush && \
    phpcs --config-set installed_paths /home/docker/.composer/vendor/drupal/coder/coder_sniffer

# Copy configs and scripts
COPY config/.ssh /home/docker/.ssh
COPY config/.drush /home/docker/.drush
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY startup.sh /opt/startup.sh

# Fix permissions after COPY
RUN sudo chown -R docker:users /home/docker

EXPOSE 9000

WORKDIR /var/www

# Set TERM so text editors/etc. can be used
ENV TERM xterm
# Default SSH key name
ENV SSH_KEY_NAME id_rsa

# Starter script
ENTRYPOINT ["/opt/startup.sh"]

# By default, launch supervisord to keep the container running.
CMD ["gosu", "root", "supervisord"]
