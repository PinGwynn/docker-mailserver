#!/bin/sh
set -e

# ==============================
# Postfix Docker Entrypoint (Alpine / hash maps)
# ==============================

# Змінні середовища
MDA_HOST=${MDA_HOST:-dovecot}
RSPAMD_HOST=${RSPAMD_HOST:-filter}
MAILNAME=${MAILNAME:-mail.example.com}
MYNETWORKS=${MYNETWORKS:-"127.0.0.0/8 [::1]/128 10.0.0.0/8"}
RECIPIENT_DELIMITER=${RECIPIENT_DELIMITER:-"+"}
SSL_CERT=${SSL_CERT:-/etc/ssl/local/le_mailserver.pem}
SSL_KEY=${SSL_KEY:-/etc/ssl/local/le_mailserver.key}
DOMAIN=${DOMAIN:-example.com}
POSTFIX_DATA=${POSTFIX_DATA:-/etc/postfix/maps}
FILTER=${FILTER:-true}
FILTER_MIME=${FILTER_MIME:-false}
RELAYHOST=${RELAYHOST:-false}

# Таймінги / обмеження
POSTFIX_STRESS=${POSTFIX_STRESS:-10s}
POSTFIX_HARD_LIMIT=${POSTFIX_HARD_LIMIT:-20}
POSTFIX_SOFT_LIMIT=${POSTFIX_SOFT_LIMIT:-2}

# Створюємо /etc/mailname якщо не існує
if [ ! -f /etc/mailname ]; then
    echo "${MAILNAME}" > /etc/mailname
fi

# ==============================
# Основні параметри
# ==============================
postconf -e "myhostname=${MAILNAME}"
postconf -e "myorigin=/etc/mailname"
postconf -e "inet_interfaces=all"
postconf -e "inet_protocols=ipv4"
postconf -e "mynetworks=${MYNETWORKS}"
postconf -e "recipient_delimiter=${RECIPIENT_DELIMITER}"
postconf -e "mydestination=local.\$myhostname"
postconf -e "broken_sasl_auth_clients=yes"
postconf -e "strict_rfc821_envelopes=yes"

# ==============================
# Віртуальні домени / доставка
# ==============================
postconf -e "virtual_mailbox_domains=${DOMAIN}"
postconf -e "virtual_mailbox_base=/var/mail"
postconf -e "alias_maps=hash:/etc/aliases"
postconf -e "virtual_mailbox_limit=0"
postconf -e "virtual_alias_domains="
postconf -e "virtual_alias_maps=hash:${POSTFIX_DATA}/virtual_alias_maps"
postconf -e "virtual_mailbox_maps="
postconf -e "canonical_maps=hash:${POSTFIX_DATA}/canonical_maps"
postconf -e "virtual_transport=lmtp:inet:${MDA_HOST}:2003"
postconf -e "header_checks=pcre:/etc/postfix/maps/header_checks_client"
postconf -e "sender_bcc_maps=hash:/etc/postfix/sender_bcc"

# ==============================
# SASL (Postfix -> Dovecot)
# ==============================
postconf -e "smtpd_sasl_type=dovecot"
postconf -e "smtpd_sasl_auth_enable=yes"
postconf -e "smtpd_sasl_path=inet:${MDA_HOST}:12345"
postconf -e "smtpd_sasl_security_options=noanonymous"
postconf -e "smtpd_sasl_local_domain=\$myhostname"
postconf -e "smtpd_sasl_authenticated_header=yes"

# ==============================
# TLS / шифрування
# ==============================
postconf -e "smtpd_use_tls=yes"
postconf -e "smtpd_tls_cert_file=${SSL_CERT}"
postconf -e "smtpd_tls_key_file=${SSL_KEY}"
postconf -e "smtpd_tls_auth_only=yes"
postconf -e "smtpd_tls_ciphers=high"
postconf -e "smtpd_tls_mandatory_protocols=!SSLv2, !SSLv3"
postconf -e "smtp_tls_security_level=may"
postconf -e "smtp_tls_mandatory_ciphers=high"
postconf -e "smtp_tls_mandatory_exclude_ciphers=RC4, MD5, DES"
postconf -e "smtp_tls_exclude_ciphers=aNULL, RC4, MD5, DES, 3DES"
postconf -e "tls_random_source=dev:/dev/urandom"
postconf -e "smtp_tls_session_cache_database=btree:\${data_directory}/smtp_scache"
postconf -e "smtpd_tls_session_cache_database=btree:\${data_directory}/smtpd_scache"
postconf -e "smtpd_tls_received_header=yes"

# ==============================
# Milter / антиспам (RSPAMD)
# ==============================
if [ "${FILTER}" = "true" ]; then
    postconf -e "smtpd_milters=inet:${RSPAMD_HOST}:11332"
    postconf -e "non_smtpd_milters=inet:${RSPAMD_HOST}:11332"
    postconf -e "milter_protocol=6"
    postconf -e "milter_mail_macros=i {mail_addr} {client_addr} {client_name} {auth_authen}"
    postconf -e "milter_default_action=accept"
fi

# ==============================
# Логування
# ==============================
postconf -e "maillog_file=/dev/stdout"

# ==============================
# Таймінги черги / розміри листів
# ==============================
postconf -e "soft_bounce=no"
postconf -e "message_size_limit=52428800"
postconf -e "mailbox_size_limit=0"
postconf -e "maximal_queue_lifetime=1h"
postconf -e "bounce_queue_lifetime=1h"
postconf -e "maximal_backoff_time=15m"
postconf -e "minimal_backoff_time=5m"
postconf -e "queue_run_delay=5m"

# ==============================
# Обмеження / безпека
# ==============================
postconf -e "smtpd_recipient_restrictions=reject_unknown_sender_domain, reject_unknown_recipient_domain, reject_unauth_destination, permit_mynetworks, permit_sasl_authenticated"
postconf -e "smtpd_sender_restrictions=reject_unknown_sender_domain"
postconf -e "smtpd_client_restrictions=check_client_access hash:${POSTFIX_DATA}/access, permit_mynetworks, reject_unauth_pipelining"
postconf -e "smtpd_data_restrictions=permit_sasl_authenticated, permit_mynetworks, reject_unauth_pipelining"
postconf -e "smtpd_relay_restrictions=check_recipient_access hash:${POSTFIX_DATA}/access, reject_non_fqdn_sender, reject_unknown_sender_domain, permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination"

postconf -e "smtpd_timeout=30"
postconf -e "smtpd_hard_error_limit=${POSTFIX_HARD_LIMIT}"
postconf -e "smtpd_soft_error_limit=${POSTFIX_SOFT_LIMIT}"
postconf -e "smtpd_error_sleep_time=${POSTFIX_STRESS}"
postconf -e "smtpd_recipient_limit=100"
postconf -e "smtpd_helo_required=yes"
postconf -e "disable_vrfy_command=yes"
postconf -e "postscreen_greet_banner= Pregreet. Please wait..."
postconf -e "postscreen_greet_action= drop"
postconf -e "postscreen_greet_wait= \${stress?4}\${stress:7}s"
postconf -e "postscreen_post_queue_limit=300"
postconf -e "postscreen_pre_queue_limit=300"

# ==============================
# MIME фільтри
# ==============================
if [ "${FILTER_MIME}" = "true" ]; then
    postconf -e "mime_header_checks=regexp:/etc/postfix/mime_header_checks"
fi

# ==============================
# Relayhost
# ==============================
if [ "${RELAYHOST}" != "false" ]; then
    postconf -e "relayhost=${RELAYHOST}"
fi

# ==============================
# Чекаємо сертифікат
# ==============================
while [ ! -e "${SSL_CERT}" ]; do
    echo "Waiting for TLS certificate..."
    sleep 5
done

# ==============================
# Генеруємо hash карти
# ==============================
for f in aliases canonical_maps virtual_alias_maps virtual_mailbox_maps access header_checks_client sender_bcc; do
    if [ -f "${POSTFIX_DATA}/$f" ]; then
        postmap "${POSTFIX_DATA}/$f"
    fi
done

# Чекаємо, поки ім’я dovecot резолвиться
until getent hosts dovecot >/dev/null 2>&1; do
    echo "Waiting for dovecot..."
    sleep 1
done

# Чекаємо, поки ім’я filter резолвиться
until getent hosts filter >/dev/null 2>&1; do
    echo "Waiting for filter..."
    sleep 1
done

# ==============================
# Запуск Postfix
# ==============================
exec /usr/sbin/postfix start-fg

