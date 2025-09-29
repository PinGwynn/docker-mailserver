#!/bin/sh

set -ex

trap 'echo "Stopping Dovecot..."; /usr/sbin/dovecot stop; exit 0' SIGTERM SIGINT

# ==============================
# Змінні середовища
# ==============================
POSTMASTER=${POSTMASTER:-postmaster@example.com}
MAILNAME=${MAILNAME:-mail.example.com}
SUBMISSION_HOST=${SUBMISSION_HOST:-postfix}
RECIPIENT_DELIMITER=${RECIPIENT_DELIMITER:-"+"}
ENABLE_IMAP=${ENABLE_IMAP:-true}
ENABLE_POP3=${ENABLE_POP3:-true}
SSL_CERT=${SSL_CERT:-/etc/ssl/local/le_mailserver.pem}
SSL_KEY=${SSL_KEY:-/etc/ssl/local/le_mailserver.key}

# ==============================
# Підставляємо змінні в конфіги
# ==============================
sed -i "s|_POSTMASTER_|${POSTMASTER}|g" /etc/dovecot/conf.d/15-lda.conf
sed -i "s|_MAILNAME_|${MAILNAME}|g" /etc/dovecot/conf.d/15-lda.conf
sed -i "s|_SUBMISSION_HOST_|${SUBMISSION_HOST}|g" /etc/dovecot/conf.d/15-lda.conf
sed -i "s|_RECIPIENT_DELIMITER_|${RECIPIENT_DELIMITER}|g" /etc/dovecot/conf.d/15-lda.conf
sed -i "s|_SUBMISSION_HOST_|${SUBMISSION_HOST}|g" /etc/dovecot/conf.d/20-submission.conf
sed -i "s|_SSL_CERT_|${SSL_CERT}|g" /etc/dovecot/conf.d/10-ssl.conf
sed -i "s|_SSL_KEY_|${SSL_KEY}|g" /etc/dovecot/conf.d/10-ssl.conf

# ==============================
# Bootstrap: додаткові сервіси тільки при першому запуску
# ==============================
if [ ! -e /etc/dovecot/docker_bootstrapped ]; then
    touch /etc/dovecot/docker_bootstrapped

    # IMAP
    if [ "$ENABLE_IMAP" = "true" ]; then
        cat >> /etc/dovecot/conf.d/10-master.conf <<EOF
service imap-login {
  inet_listener imap {
    #port = 143
  }
  inet_listener imaps {
    #port = 993
    #ssl = yes
  }
}
service imap {
}
protocols = \$protocols imap
EOF
    fi

    # POP3
    if [ "$ENABLE_POP3" = "true" ]; then
        cat >> /etc/dovecot/conf.d/10-master.conf <<EOF
service pop3-login {
  inet_listener pop3 {
    #port = 110
  }
  inet_listener pop3s {
    #port = 995
    #ssl = yes
  }
}
service pop3 {
}
protocols = \$protocols pop3
EOF
    fi

    # LMTP TCP для Postfix
    cat >> /etc/dovecot/conf.d/10-master.conf <<EOF
service lmtp {
  inet_listener lmtp {
    port = 2003
  }
}
EOF

    # SASL TCP для Postfix
    cat >> /etc/dovecot/conf.d/10-master.conf <<EOF
service auth {
  inet_listener auth {
    port = 12345
  }
}
EOF
fi

while [ ! -e ${SSL_CERT} ]; do
	echo "wait file sert"
	sleep 5
done


### Fix directory permissions

# Основний каталог
chgrp dovecot /var/vmail
chmod 2770 /var/vmail

# Створення директорії для домену, якщо її немає
if [ -n "$DOMAIN" ]; then
    DOMAIN_DIR="/var/vmail/${DOMAIN}"
    if [ ! -d "$DOMAIN_DIR" ]; then
        mkdir -p "$DOMAIN_DIR"
    fi
fi

# Каталоги доменів / користувачів (перший рівень)
find /var/vmail -mindepth 1 -maxdepth 1 -type d \
  -exec chgrp dovecot {} \; \
  -exec chmod 2775 {} \;    # drwxrwsr-x, група vmail має x

# Файли passwd
find /var/vmail -type f -name "passwd" -exec chown root:dovecot {} \; -exec chmod 640 {} \;

# exec su-exec dovecot:dovecot /usr/sbin/dovecot -F
exec /usr/sbin/dovecot -F
