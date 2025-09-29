#!/bin/bash

if ! [ -d ./data/maildir ]; then
         mkdir ./data/maildir
         chmod 777 ./data/maildir
fi

chmod 777 ./data/filter/dkim

read -p "Please enter FQDN hostname: " MAILNAME
read -p "Please enter mail domain: " DOMAIN
read -p "Please enter RSPAMD web access password: " RSPAMD_PASS
echo "Please enter the ip addresses separated by a space to access"
echo "the service rspamd."
read -p "Default, access to them is closed: " ip_allow
read -p "Please enter CF zone token: " CF_TOKEN
read -p "Please enter CF Zone ID: " CF_ZONE_ID

cp $PWD/.env.dist $PWD/.env
sed -i "s|_PASS_|$PASS|g" $PWD/.env
sed -i "s|_RSPAMD_|$RSPAMD_PASS|g" $PWD/.env
sed -i "s|_DOMAIN_|$DOMAIN|g" $PWD/.env
sed -i "s|_MAILNAME_|$MAILNAME|g" $PWD/.env
sed -i "s|_CF_TOKEN_|$CF_TOKEN|g" $PWD/.env
sed -i "s|_CF_ZONE_ID_|$CF_ZONE_ID|g" $PWD/.env

set -o allexport
source .env
set +o allexport

echo "Generate strong dhparams.pem with command:"
echo "openssl dhparam -out ./data/certs/dhparams.pem 4096"
echo
echo "Build docket images:"
echo "docker compose build acme"
echo "docker compose build acme-init"
echo 
echo "Issue SSL certificats for ${MAILNAME} with command:"
echo "docker compose --profile init up acme-init"
echo
echo "You can start the build and run with the command:"
echo "docker compose up -d"
