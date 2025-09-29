#!/bin/bash

# reload-services.sh - перезавантаження mail сервісів після оновлення сертифікату
set -e

DOMAIN="${1:-unknown}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$TIMESTAMP] $1" | tee -a /var/log/cert-reload.log
}

log "Certificate renewed for domain: $DOMAIN"

# Функція для безпечного виконання команд
safe_exec() {
    local container="$1"
    local command="$2"
    local description="$3"
    
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        log "Executing: $description"
        if docker exec "$container" $command; then
            log "✅ Success: $description"
        else
            log "⚠️  Command failed, trying container restart: $container"
            docker restart "$container" && log "✅ Restarted: $container"
        fi
    else
        log "⚠️  Container not found or not running: $container"
    fi
}

# Встановлюємо правильні права на файли сертифікатів
if [ -f "/certs/${DOMAIN}.key" ]; then
    chmod 600 "/certs/${DOMAIN}.key"
    chmod 644 "/certs/${DOMAIN}.cert" "/certs/${DOMAIN}.fullchain" "/certs/${DOMAIN}.ca" 2>/dev/null || true
    log "Certificate file permissions updated"
fi

# Перезавантажуємо Postfix
safe_exec "postfix" "postfix reload" "Postfix reload"

# Перезавантажуємо Dovecot  
safe_exec "dovecot" "doveadm reload" "Dovecot reload"

# Можна додати інші сервіси
# safe_exec "nginx" "nginx -s reload" "Nginx reload"
# safe_exec "apache" "httpd -k graceful" "Apache graceful restart"

log "Certificate renewal process completed for $DOMAIN"

# Опціонально: відправка уведомлення
if [ -n "$WEBHOOK_URL" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"✅ SSL certificate renewed for $DOMAIN and mail services reloaded\"}" \
        "$WEBHOOK_URL" 2>/dev/null || true
fi
