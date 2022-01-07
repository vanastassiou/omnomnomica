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

sudo apt update
sudo apt install -y zip unzip
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
sudo apt install -y apache2
sudo mkdir -p "${APACHE_WEBSITE_DIR}"
sudo mv "${TEMP_DIR}/public_html" "${APACHE_WEBSITE_DIR}/public_html"
sudo mv "${TEMP_DIR}/${WEBSITE_DOMAIN}"*.conf "/etc/apache2/sites-available/"
sudo a2ensite "${WEBSITE_DOMAIN}.*" # Enables both HTTP and HTTPS virtual hosts files
sudo a2enmod rewrite
sudo mkdir "${APACHE_WEBSITE_DIR}"/logs
sudo chown -R www-data: "${APACHE_WEBSITE_DIR}"
sudo systemctl reload apache2

# Set up SSL/TLS certs with Let's Encrypt, redirect HTTP -> HTTPS
sudo apt install -y certbot python3-certbot-apache
sudo certbot --non-interactive --agree-tos -m vanastassiou+letsencrypt@gmail.com --apache -d "${WEBSITE_DOMAIN}" --keep-until-expiring --redirect # Avoid requesting new cert needlessly to prevent rate limiting

# Install prerequisites for WordPress

sudo apt install -y php7.4-cli
sudo apt install -y mysql-server

MYSQL_ROOT_PASSWORD=$(sudo cat /etc/mysql/debian.cnf | grep -Po 'password = \K[^ ]+' | head -n 1)

## Extract existing values from wp-config.php
WP_CONFIG_FILE="${APACHE_WEBSITE_DIR}/public_html/wp-config.php"
WP_DB_USER=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_USER', '\\K.*(?=')")
WP_DB_NAME=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_NAME', '\\K.*(?=')")
WP_DB_PASSWORD=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_PASSWORD', '\\K.*(?=')")
WP_DB_HOST=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_HOST', '\\K.*(?=')")
WP_DB_CHARSET=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_CHARSET', '\\K.*(?=')")
WP_DB_COLLATE=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_COLLATE', '\\K.*(?=')")

## Configure ~/.my.cnf for passwordless log
cat > ~/.my.cnf << MY_CONF
[client]
user=root
password=${MYSQL_ROOT_PASSWORD}

[client]
user=${WP_DB_USER}
password=${WP_DB_PASSWORD}

[mysqldump]
user=${WP_DB_USER}
password=${WP_DB_PASSWORD}
MY_CONF

sudo chmod 600 ~/.my.cnf

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
