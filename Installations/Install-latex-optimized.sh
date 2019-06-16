#!/bin/bash

# Make sure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Update Package Lists
apt-get update -y

# Install latex base package
apt-get install texlive-latex-base -y

# Install latex minimum required packages
apt-get install --no-install-recommends texlive-latex-extra -y

# Install latex minimum required packages
apt-get install --no-install-recommends  texlive-fonts-recommended -y