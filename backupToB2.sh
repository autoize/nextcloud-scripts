#!/bin/sh

# NextCloud to BackBlaze B2 Backup Script
# Author: Autoize (autoize.com)

# This script creates an incremental backup of your NextCloud instance at BackBlaze's off-site location.
# BackBlaze B2 is an object storage service that is much less expensive than using Amazon S3 for the same purpose, with similar versioning and lifecycle management features.
# Uploads are free, and storage costs only $0.005/GB/month compared to S3's $0.022/GB/month.

# Requirements
# - BackBlaze B2 account (10 GB Free) - Create one at https://www.backblaze.com/b2/sign-up.html
# - Python 3.x and Python PIP - sudo apt-get install python3 && wget https://bootstrap.pypa.io/get-pip.py && sudo python3 get-pip.py
# - BackBlaze B2 CLI installed from PyPI - sudo pip install b2

# Instructions
# 1. Insert the following line in your NextCloud config.php file above the ); to move the cache above each user's data directory.
#    If /media/external/CloudDATA is not your data directory, substitute the relevant directory before /cache.
#	'cache_path' => '/media/external/CloudDATA/cache',
# 2. Create a bucket and obtain your Account ID and Application Key from your B2 account.
# 3. Authenticate your CLI using the b2 authorize_account command.
# 4. Save this script to a safe directory such as /srv/backupToB2.sh and make it executable with the following command.
#      sudo chmod +x backupToB2.sh
# 5. This script must be run as root. To run a backup now:
#      sudo ./backupToB2.sh
# 6. Set up a cron job to run this backup on a predefined schedule (optional).
#      sudo crontab -u root -e
#    Add the following line to the crontab to conduct a weekly backup every Saturday at 2:00am. 
#      0 2 * * sat root sh /srv/backupToB2.sh > /srv/backupToB2.log
#    Save, quit and check that the crontab has been installed using the following command.
#      sudo crontab -u root -l

# Name of BackBlaze B2 Bucket
b2_bucket='b2_bucket_name'

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

# Dump database and backup to B2

mysqldump --single-transaction -h$db_host -u$db_user -p$db_pass $db_name > nextcloud.sql
b2 upload_file $b2_bucket nextcloud.sql NextCloudDB/nextcloud.sql
rm nextcloud.sql

# Sync data to B2, then disable maintenance mode
# NextCloud will be unavailable during the sync. This will take a while if you added much data since your last backup.
# If /media/external/CloudDATA is not your data directory, modify the --excludeRegex flag accordingly, which excludes the NC cache from getting synced to B2.

b2 sync --excludeRegex '\/media\/external\/CloudDATA\/cache\/.*' $data_dir b2://$b2_bucket$data_dir
sudo -u www-data php $nextcloud_dir/occ maintenance:mode --off

date +'%a %b %e %H:%M:%S %Z %Y'
echo 'Finished'
