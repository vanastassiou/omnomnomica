#!/bin/env bash
#
# Backs up the sitefiles and MySQL database for a WordPress website to an
# AWS S3 bucket. Files are archived to reduce S3's per-request charges.
# Currently takes a full backup only if changes are detected. A future 
# incremental backup strategy will likely rely on AWS's managed services.
#
# Terraform uploads this script to the EC2 instance upon creation, and
# restore-website.sh configures the appropriate cron job for a nightly run.

TIMESTAMP="$(date '+%Y-%m-%d_%H:%M:%S')"
TEMP_DIR="/tmp"
WEBSITE_DOMAIN="omnomnomi.ca" #TODO: parameterize this better to support multiple deployment envs
WEBSITE_ROOT="/var/www/${WEBSITE_DOMAIN}"
VHOST_FILE_LOCATION="/etc/apache2/sites-available/"
S3_BUCKET_NAME="omnomnomica-backups"

# Add site files and Apache virtual host config files to one zip archive
SITEFILES_ZIP="${WEBSITE_DOMAIN}-${TIMESTAMP}.zip"

echo "INFO: Creating archive of website document root and virtual hosts files"

cd ${WEBSITE_ROOT}
zip -r "${TEMP_DIR}/${SITEFILES_ZIP}" public_html >/dev/null 2>&1

cd ${VHOST_FILE_LOCATION}
zip -u "${TEMP_DIR}/${SITEFILES_ZIP}" "${WEBSITE_DOMAIN}"* >/dev/null 2>&1

## Check zipfile integrity

echo "INFO: Testing archive integrity"
unzip -t "${TEMP_DIR}/${SITEFILES_ZIP}" >/dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "SUCCESS: Verified integrity of ${SITEFILES_ZIP} archive"
else
  echo "ERROR: ${SITEFILES_ZIP} failed its integrity check"
  exit $?
fi

# Dump database to file
WEBSITE_DB_DUMP="${WEBSITE_DOMAIN}-${TIMESTAMP}.sql"
WP_CONFIG_FILE="${WEBSITE_ROOT}/public_html/wp-config.php"
WP_DB_USER=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_USER', '\\K.*(?=')")
WP_DB_NAME=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_NAME', '\\K.*(?=')")
WP_DB_HOST=$(cat "${WP_CONFIG_FILE}" | grep -Po "DB_HOST', '\\K.*(?=')")

## Use ~/.my.cnf instead of CLI auth, set up during restore-website.sh
echo "INFO: Dumping ${WP_DB_NAME} database to file"
sudo mysqldump "${WP_DB_NAME}" > "${TEMP_DIR}/${WEBSITE_DB_DUMP}"
echo "SUCCESS: Dump complete"

# Compare sizes of newly created zipfile and dumpfile against most recently
# retrieved backups, which were downloaded as part of restore.sh. Clean up and
# exit if sizes are identical.
echo "INFO: Comparing new backup files to old"

BACKUPS_DIR="/home/ubuntu/backups"
OLD_SITEFILES_ZIP_SIZE=$(stat "${BACKUPS_DIR}/${WEBSITE_DOMAIN}"*.zip --format="%s")
OLD_WEBSITE_DB_DUMP_SIZE=$(stat "${BACKUPS_DIR}/${WEBSITE_DOMAIN}"*.sql --format="%s")

NEW_SITEFILES_ZIP_SIZE=$(stat "${TEMP_DIR}/${SITEFILES_ZIP}" --format="%s")
NEW_WEBSITE_DB_DUMP_SIZE=$(stat "${TEMP_DIR}/${WEBSITE_DB_DUMP}" --format="%s")

if [ ${OLD_SITEFILES_ZIP_SIZE} -eq ${NEW_SITEFILES_ZIP_SIZE} ] && [ ${OLD_WEBSITE_DB_DUMP_SIZE} -eq ${NEW_WEBSITE_DB_DUMP_SIZE} ]; then
  echo "ERROR: No changes detected to website since last restore. Cancelling backup."
  rm "${TEMP_DIR}/${SITEFILES_ZIP}" "${TEMP_DIR}/${WEBSITE_DB_DUMP}"
  exit $?
fi

echo "SUCCESS: New files different from old; proceeding with upload to ${S3_BUCKET_NAME}"

# Transfer files to S3 bucket. AWS CLI install/S3 user config not required,
# as these were done during provisioning in restore-website.sh
aws s3 cp "${TEMP_DIR}/${SITEFILES_ZIP}" s3://"${S3_BUCKET_NAME}"/
aws s3 cp "${TEMP_DIR}/${WEBSITE_DB_DUMP}" s3://"${S3_BUCKET_NAME}"/

# Verify transfer to S3 by checking filesizes
AWS_SITEFILES_ZIP_SIZE=$(aws s3api head-object --bucket=${S3_BUCKET_NAME} --key "${NEWEST_AWS_SITEFILES_BACKUP}" --query 'ContentLength')
AWS_WEBSITE_DB_DUMP_SIZE=$(aws s3api head-object --bucket=${S3_BUCKET_NAME} --key "${NEWEST_AWS_DUMP_BACKUP}" --query 'ContentLength')

if [ $AWS_SITEFILES_ZIP_SIZE != ${LOCAL_SITEFILES_ZIP_SIZE} ]; then
  echo "WARNING: file size mismatch for ${SITEFILES_ZIP} after upload to S3.
  The file has been uploaded, but you should verify it."
fi

if [ $AWS_WEBSITE_DB_DUMP_SIZE != ${LOCAL_WEBSITE_DB_DUMP_SIZE} ]; then
  echo "WARNING: file size mismatch for ${WEBSITE_DB_DUMP} after upload to S3.
  The file has been uploaded, but you should verify it."
fi

echo "SUCCESS: Backup complete"
