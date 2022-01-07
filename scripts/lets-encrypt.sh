#!/bin/env bash

# Cannot be run as part of restore_website.sh, because creating a new instance
# often results in a new public DNS address, and updates to the A record in
# Route 53 can take a while to propagate. 

WEBSITE_DOMAIN="omnomnomi.ca"
DIG_RESULT=$(dig +short "${WEBSITE_DOMAIN}")

# Result will be null if no record exists
if [ -z "${DIG_RESULT}" ]; then
  echo "ERROR: DNS record not found for ${WEBSITE_DOMAIN}; exiting"
  exit
fi

# Sets up SSL/TLS certs with Let's Encrypt, redirect HTTP -> HTTPS
echo "SUCCESS: DNS record found for ${WEBSITE_DOMAIN}; requesting certificate from Let's Encrypt"

sudo apt install -y certbot python3-certbot-apache
sudo certbot --non-interactive --agree-tos -m vanastassiou+letsencrypt@gmail.com --apache -d "${WEBSITE_DOMAIN}" --keep-until-expiring --redirect # Avoid requesting new cert needlessly to prevent rate limiting

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to obtain Let's Encrypt certificate."
  exit
else
  sudo rm /etc/cron.hourly/lets-encrypt.sh /etc/cron.d/lets-encrypt
fi
