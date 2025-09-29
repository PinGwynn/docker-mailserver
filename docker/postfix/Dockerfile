# ==============================
# Production-ready Postfix Dockerfile
# ==============================
FROM debian:bookworm-slim

# Аргументи для збірки
ARG DEBIAN_FRONTEND=noninteractive

# ==============================
# Встановлення пакетів
# ==============================
RUN apt-get update && apt-get install -y --no-install-recommends \
        postfix \
        postfix-pcre \
        sasl2-bin \
        rsyslog \
        db5.3-util \
        tzdata \
        procps \
        ca-certificates \
        bash \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/postfix/maps

# ==============================
# Копіюємо конфігурацію і скрипти
# ==============================
COPY rootfs/ /

# ==============================
# Порти та volume
# ==============================
EXPOSE 25 587 20587
VOLUME ["/var/spool/postfix", "/etc/postfix/maps"]

# ==============================
# Healthcheck та entrypoint
# ==============================
HEALTHCHECK CMD postfix status || exit 1
CMD ["/usr/local/bin/entrypoint.sh"]

