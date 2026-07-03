FROM dunglas/frankenphp:1-php8.3 AS frankenphp_upstream

### Base (extensions PHP, paquets système, user) ###
FROM frankenphp_upstream AS frankenphp_base

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    vim \
	acl \
    supervisor \
    procps \
	&& rm -rf /var/lib/apt/lists/*

# Create non-root user with configurable UID/GID
ARG USER_ID=1000
ARG GROUP_ID=1000

RUN groupadd -g ${GROUP_ID} www && \
    useradd -u ${USER_ID} -g www -m -s /bin/bash www && \
    chown -R www:www /app /data /config

# Extensions PHP
RUN install-php-extensions \
    @composer \
	intl \
	zip \
	opcache \
    apcu \
	pdo_pgsql \
    pcntl

# Config PHP commune dev+prod
COPY --link .docker/php/app.ini $PHP_INI_DIR/conf.d/

ENV COMPOSER_HOME=/home/www/.composer
ENV COMPOSER_ALLOW_SUPERUSER=1

HEALTHCHECK --start-period=60s CMD curl -f http://localhost:2019/metrics || exit 1
CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile" ]

### Dev Image ###
FROM frankenphp_base AS frankenphp_dev

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

USER www

CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile", "--watch" ]

### Worker Dev Image ###
FROM frankenphp_dev AS frankenphp_worker_dev
COPY --link ./.docker/supervisor.d /etc/supervisor
HEALTHCHECK --start-period=10s --interval=30s --timeout=10s --retries=3 \
  CMD pgrep -f "messenger:consume" > /dev/null || exit 1
CMD ["/usr/bin/supervisord"]

### Composer deps stage ###
FROM frankenphp_base AS composer_deps
WORKDIR /app
COPY composer.* symfony.* ./
RUN set -eux; \
	composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

### Prod Image ###
FROM frankenphp_base AS frankenphp_prod
ENV APP_ENV=prod

ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Tuning OPcache prod
COPY --link .docker/php/app.prod.ini $PHP_INI_DIR/conf.d/

# Caddyfile baked dans l'image (en dev il est monté en volume pour live edit)
COPY --link .docker/franken/Caddyfile /etc/caddy/Caddyfile

# Vendor composer pré-installé (couche cache séparée)
COPY --from=composer_deps /app/vendor ./vendor
COPY --link composer.* symfony.* ./

# Sources app
COPY --link . ./

# Nettoyage des fichiers inutiles en prod
RUN rm -rf .docker .github node_modules .git assets

# Génération autoload optimisée + post-install (cache:clear, assets:install)
RUN set -eux; \
	mkdir -p var/cache var/log; \
	composer dump-autoload --classmap-authoritative --no-dev; \
	composer run-script --no-dev post-install-cmd; \
	chmod +x bin/console; \
	chown -R www:www var public 2>/dev/null || true; \
	sync

USER www

### Worker Prod Image ###
FROM frankenphp_prod AS frankenphp_worker_prod
COPY --link ./.docker/supervisor.d /etc/supervisor
HEALTHCHECK --start-period=10s --interval=30s --timeout=10s --retries=3 \
  CMD pgrep -f "messenger:consume" > /dev/null || exit 1
CMD ["/usr/bin/supervisord"]
