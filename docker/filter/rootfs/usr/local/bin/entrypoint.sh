#!/bin/sh

if [ "${CONTROLLER_PASSWORD}" == "changeme" ]
then
    # q1 is disabled in rspamd.
     CONTROLLER_PASSWORD_ENC="q1"
else
    CONTROLLER_PASSWORD_ENC=`rspamadm pw -e -p ${CONTROLLER_PASSWORD}`
    sed -i "s|_CONTROLLER_SECURE_NETWORK_|${CONTROLLER_SECURE_NETWORK}|g" /etc/rspamd/local.d/worker-controller.inc
    sed -i "s|_CONTROLLER_PASSWORD_ENC_|${CONTROLLER_PASSWORD_ENC}|g" /etc/rspamd/local.d/worker-controller.inc
fi

if [ ${FILTER_VIRUS} == "true" ]
then
    sed -i "s|_FILTER_VIRUS_HOST_|${FILTER_VIRUS_HOST}|g" /etc/rspamd/local.d/antivirus.conf
    until ping -c1 ${FILTER_VIRUS_HOST}  > /dev/null; do
      sleep 1
    done
    echo "Virus service OK"
else
    rm /etc/rspamd/local.d/antivirus.conf
fi

if [ -r /media/dkim/mail.pub ]
  then
    echo "DKIM Certificate found."
  else
rspamadm dkim_keygen -b 2048 -s mail -k /media/dkim/mail.key | tee -a  /media/dkim/mail.pub
fi

exec /usr/bin/rspamd -c /etc/rspamd/rspamd.conf -f
