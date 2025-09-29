#!/bin/bash
set -e

# entrypoint.sh - управління acme.sh контейнером

# Функція для логування
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Ініціалізація acme.sh
init_acme() {
    if [ ! -f /acme.sh/account.conf ]; then
        log "Initializing acme.sh..."
        acme.sh --register-account -m "${ACME_EMAIL:-admin@example.com}"
        acme.sh --set-default-ca --server letsencrypt
    fi
}

# Видача нового сертифікату
issue_cert() {
    local domain="$1"
    if [ -z "$domain" ]; then
        log "ERROR: Domain not specified"
        exit 1
    fi
    
    log "Issuing certificate for domain: $domain"
    acme.sh --issue --dns dns_cf -d "$domain" \
        --cert-file "/certs/${domain}.cert" \
        --key-file "/certs/${domain}.key" \
        --fullchain-file "/certs/${domain}.fullchain" \
        --ca-file "/certs/${domain}.ca" \
        --reloadcmd "/usr/local/bin/reload-services.sh $domain"
}

# Оновлення всіх сертифікатів
renew_certs() {
    log "Renewing certificates..."
    acme.sh --cron --home /acme.sh
}

# Запуск daemon режиму
start_daemon() {
    init_acme
    
    # acme.sh автоматично встановить cron job
    acme.sh --install-cronjob
    
    log "Starting cron daemon..."
    
    # Використовуємо оригінальні флаги як у neilpang/acme.sh
    # -n = не переходити в background (foreground)
    # -s = логувати в syslog замість відправки mail
    # -m off = вимкнути mail відправку
    exec crond -n -s -m off
}

# Основна логіка
case "$1" in
    "daemon")
        start_daemon
        ;;
    "issue")
        init_acme
        issue_cert "$2"
        ;;
    "renew")
        renew_certs
        ;;
    "init")
        init_acme
        ;;
    *)
        # Передаємо команду безпосередньо acme.sh
        exec acme.sh "$@"
        ;;
esac
