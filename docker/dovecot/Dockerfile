ARG ALPINE_VER=3.18

FROM alpine:${ALPINE_VER}

RUN apk add --no-cache --update \
         tzdata \
         curl \
         dovecot \
         dovecot-lmtpd \
         dovecot-pigeonhole-plugin \
         dovecot-pop3d \
         dovecot-submissiond \
         shadow \
         su-exec && \
    adduser -h /var/vmail -u 5000 -D vmail && \
    usermod -aG vmail dovecot && \
    rm -rf /etc/ssl/dovecot

COPY rootfs/ /

RUN sievec /etc/dovecot/sieve/global/spam-to-folder.sieve && \
    sievec /etc/dovecot/sieve/global/learn-ham.sieve && \
    sievec /etc/dovecot/sieve/global/learn-spam.sieve

EXPOSE 2003 4190 143 110 993 995
VOLUME ["/var/vmail"]

HEALTHCHECK CMD echo "? LOGOUT" | nc 127.0.0.1 143 | grep "Dovecot ready."
CMD ["/usr/local/bin/entrypoint.sh"]
