#!/bin/bash

# Make sure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Set some temparary variables to use during the script
WEB_USER="www-data"
WEB_DIR="/var/www/html"
CONFIG_FILE="laravel-workers.conf"
CONFIG_PATH="/etc/supervisor/conf.d/$CONFIG_FILE"
WORKER_NAME="laravel-workers"


# Update Package Lists
apt-get update -y

# Reconfigure dpkg
# Encountered error when directly installing supervisor on live AMI
# This resolved that issue
dpkg --configure -a

# Install some base packages to help setup the sandbox
apt-get install supervisor -y

# Setup the supervisor configuration file  
cat > $CONFIG_PATH << EOF
[program:$WORKER_NAME]
process_name=%(program_name)s_%(process_num)02d
command=php $WEB_DIR/artisan queue:work sqs --sleep=3 --tries=3 --daemon
autostart=true
autorestart=true
user=phmlink
numprocs=8
redirect_stderr=true
stdout_logfile=$WEB_DIR/storage/logs/queue-worker.log
EOF

# Make worker available
supervisorctl reread

# Add worker in the process group
supervisorctl update

# Start the worker process
supervisorctl start $WORKER_NAME:*