#!/bin/env bash
#
# Restores website and configures SSL/TLS certificates. Runs on EC2
# instance after spinup as part of provisioning aws_instance.web (defined
# in compute.tf), but can be run at any time thereafter, assuming the files
# in $BACKUPS_DIR have not been altered or removed.

BACKUPS_DIR="/home/ubuntu/backups"

if [[ ! -e $BACKUPS_DIR ]]; then
    mkdir $BACKUPS_DIR
fi

TEMP_DIR="/tmp"
S3_BUCKET_NAME="omnomnomica-backups"

WEBSITE_DOMAIN="omnomnomi.ca"
APACHE_WEBSITE_DIR="/var/www/${WEBSITE_DOMAIN}"

# Install AWS CLI and configure with S3 IAM user for backups

## Necessary because AWS uses cloud-init to populate the list of package
## sources, which takes a few seconds to run after instance spinup and can cause
## issues when automating deployment. 
##
## Reference:  https://forum.gitlab.com/t/install-zip-unzip/13471/9
cloud-init status --wait

sudo apt update && sudo apt install -y zip unzip  >/dev/null 2>&1
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update
rm -rf awscliv2.zip 
rm -rf aws

if ! command -v aws --version >/dev/null 2>&1; then
  echo "ERROR: failed to install AWS CLI; exiting"
  exit $?
fi

aws --profile default configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
aws --profile default configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"

command -v aws s3 ls --profile=default >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: failed to configure S3 user for AWS CLI; exiting"
  exit $?
fi

## Download most recent sitefiles archive and SQL dump files
DUMP_BACKUP=$(aws s3 ls ${S3_BUCKET_NAME} | grep sql | sort | tail -n 1 | awk '{print $4}')
SITEFILES_BACKUP=$(aws s3 ls ${S3_BUCKET_NAME} | grep zip | sort | tail -n 1 | awk '{print $4}')

aws s3 cp s3://"${S3_BUCKET_NAME}"/"${SITEFILES_BACKUP}" "${BACKUPS_DIR}"
aws s3 cp s3://"${S3_BUCKET_NAME}"/"${DUMP_BACKUP}" "${BACKUPS_DIR}"

# Extract site files
unzip "${BACKUPS_DIR}"/"${SITEFILES_BACKUP}" -d "${TEMP_DIR}"
cp "${BACKUPS_DIR}"/"${DUMP_BACKUP}" "${TEMP_DIR}"

# Set up Apache
sudo apt install -y apache2  >/dev/null 2>&1
sudo mkdir -p "${APACHE_WEBSITE_DIR}"
sudo mv "${TEMP_DIR}/public_html" "${APACHE_WEBSITE_DIR}/public_html"
sudo mv "${TEMP_DIR}/${WEBSITE_DOMAIN}"*.conf "/etc/apache2/sites-available/"
sudo a2ensite "${WEBSITE_DOMAIN}.*" # Enables both HTTP and HTTPS virtual hosts files
sudo a2enmod rewrite
sudo mkdir "${APACHE_WEBSITE_DIR}"/logs
sudo chown -R www-data: "${APACHE_WEBSITE_DIR}"
sudo systemctl reload apache2

# Install prerequisites for WordPress

sudo apt install -y php libapache2-mod-php php-mysql mysql-server  >/dev/null 2>&1

## Extract existing values from wp-config.php
WP_CONFIG_FILE="${APACHE_WEBSITE_DIR}/public_html/wp-config.php"
WP_DB_USER=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_USER', '\\K.*(?=')")
WP_DB_NAME=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_NAME', '\\K.*(?=')")
WP_DB_PASSWORD=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_PASSWORD', '\\K.*(?=')")
WP_DB_HOST=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_HOST', '\\K.*(?=')")
WP_DB_CHARSET=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_CHARSET', '\\K.*(?=')")

## Create user and DB
sudo mysql -u root << MYSQL_SETUP
CREATE DATABASE IF NOT EXISTS ${WP_DB_NAME} DEFAULT CHARACTER SET ${WP_DB_CHARSET};
CREATE USER IF NOT EXISTS ${WP_DB_USER}@${WP_DB_HOST} IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${WP_DB_NAME}.* TO ${WP_DB_USER}@${WP_DB_HOST};
FLUSH PRIVILEGES;
MYSQL_SETUP

## Import DB dump
WP_SITE_DB_DUMP="${TEMP_DIR}"/"${DUMP_BACKUP}"
mysql -u "${WP_DB_USER}" -h"${WP_DB_HOST}" "${WP_DB_NAME}" < "${WP_SITE_DB_DUMP}"

# Configure nightly backup
sudo mv /home/ubuntu/back-up-website.sh /etc/cron.daily/
sudo chown root:root /etc/cron.daily/back-up-website.sh && sudo chmod 755 /etc/cron.daily/back-up-website.sh

sudo cat > /etc/cron.d/nightly-backup << BACKUPS_CRON
SHELL=/bin/bash
0 0 0 * *   root    /etc/cron.daily/back-up-website.sh
BACKUPS_CRON

# Configure Let's Encrypt setup
sudo mv /home/ubuntu/lets-encrypt.sh /etc/cron.hourly/
sudo chown root:root /etc/cron.hourly/lets-encrypt.sh && sudo chmod 755 /etc/cron.hourly/lets-encrypt.sh

sudo cat > /etc/cron.d/lets-encrypt << LETS_ENCRYPT
SHELL=/bin/bash
0 0/10 * * *   root    /etc/cron.hourly/lets_encrypt.sh
LETS_ENCRYPT
