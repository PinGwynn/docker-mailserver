ARG ALPINE_VER=3.18

FROM alpine:${ALPINE_VER}

ENV FILTER_VIRUS=true

RUN apk add --no-cache --update \
      tzdata \
      clamav-daemon \
      clamav-libunrar && \
    rm -rf /var/log/clamav

COPY rootfs/ /

EXPOSE 3310
USER clamav

RUN /usr/bin/freshclam -l /dev/null

VOLUME ["/var/lib/clamav"]

HEALTHCHECK CMD echo PING | nc 127.0.0.1 3310 | grep PONG
CMD ["/usr/local/bin/entrypoint.sh"]
