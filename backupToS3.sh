#!/bin/sh

# NextCloud to Amazon S3 Backup Script
# Author: Autoize (autoize.com)

# This script creates an incremental backup of your NextCloud instance to Amazon S3.
# Amazon S3 is a highly redundant block storage service with versioning and lifecycle management features.

# Requirements
# - Amazon AWS Account and IAM User with AmazonS3FullAccess privilege
# - Python 2.x and Python PIP - sudo apt-get install python && wget https://bootstrap.pypa.io/get-pip.py && sudo python get-pip.py
# - s3cmd installed from PyPI - sudo pip install s3cmd

# Name of Amazon S3 Bucket
s3_bucket='s3_bucket_name'

# Path to NextCloud installation
nextcloud_dir='/var/www/nextcloud'

# Path to NextCloud data directory
data_dir='/media/external/CloudDATA'

# MySQL/MariaDB Database credentials
db_host='localhost'
db_user='nextclouduser'
db_pass='secret'
db_name='nextcloud'

# Check if running as root

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo 'Started'
date +'%a %b %e %H:%M:%S %Z %Y'

# Put NextCloud into maintenance mode. 
# This ensures consistency between the database and data directory.

sudo -u www-data php $nextcloud_dir/occ maintenance:mode --on

# Dump database and backup to S3

mysqldump --single-transaction -h$db_host -u$db_user -p$db_pass $db_name > nextcloud.sql
s3cmd put nextcloud.sql s3://$s3_bucket/NextCloudDB/nextcloud.sql
rm nextcloud.sql

# Sync data to S3 in place, then disable maintenance mode 
# NextCloud will be unavailable during the sync. This will take a while if you added much data since your last backup.

# If upload cache is in the default subdirectory, under each user's folder (Default)
s3cmd sync --recursive --preserve --exclude '*/cache/*' $data_dir s3://$s3_bucket/

# If upload cache for all users is stored directly as an immediate subdirectory of the data directory
# s3cmd sync --recursive --preserve --exclude 'cache/*' $data_dir s3://$s3_bucket/

sudo -u www-data php $nextcloud_dir/occ maintenance:mode --off

date +'%a %b %e %H:%M:%S %Z %Y'
echo 'Finished'
