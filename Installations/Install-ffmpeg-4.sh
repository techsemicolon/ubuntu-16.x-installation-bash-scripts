#!/bin/bash

# Make sure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Update Package Lists
apt-get update -y

# Install add-apt-repository dependencies
apt-get install software-properties-common -y
apt-get install python-software-properties -y

# Add  PHP repositories
LC_ALL=C.UTF-8 add-apt-repository ppa:jonathonf/ffmpeg-4 -y

# Update Package Lists
apt-get update -y

# Install ffmpeg-4
apt-get install ffmpeg -y