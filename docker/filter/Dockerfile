ARG ALPINE_VER=3.18

FROM alpine:${ALPINE_VER}

ENV FILTER_VIRUS=false \
    FILTER_VIRUS_HOST=virus.local \
    CONTROLLER_PASSWORD=changeme

RUN apk add --no-cache --update \
      tzdata \
      iputils \
      openssl \
      rspamd \
      rspamd-client \
      rspamd-controller \
      rspamd-proxy && \
    mkdir /run/rspamd && \
    apk --no-cache del \
      openssl

COPY rootfs/ /

RUN chown -R rspamd \
      /etc/rspamd/local.d/ \
      /run/rspamd \
      /var/lib/rspamd

EXPOSE 11332 11334
USER rspamd

VOLUME ["/var/lib/rspamd"]

HEALTHCHECK CMD wget -O- -T 10 http://127.0.0.1:11334/stat
CMD ["/usr/local/bin/entrypoint.sh"]
