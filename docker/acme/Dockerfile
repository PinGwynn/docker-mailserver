FROM neilpang/acme.sh:latest

# Встановлюємо docker CLI та інші корисні утиліти
RUN apk add --no-cache \
    docker-cli \
    curl \
    jq \
    bash \
    && rm -rf /var/cache/apk/*

# Копіюємо наші скрипти
COPY rootfs/ /

# Встановлюємо робочу директорію
WORKDIR /acme.sh

# Змінюємо entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["daemon"]
