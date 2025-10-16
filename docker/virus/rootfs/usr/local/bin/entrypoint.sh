#!/bin/sh

if [ "${FILTER_VIRUS}" = "false" ]
then
    echo "Virus filtering is disabled, sleeping..."
    exec sleep infinity
fi

/usr/bin/freshclam -d -l /dev/stdout &
/usr/sbin/clamd
