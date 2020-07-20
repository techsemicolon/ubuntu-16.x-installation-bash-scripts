#!/bin/bash

# Make sure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Update Package Lists
apt-get update -y

# Install add-apt-repository dependencies
apt-get install install build-essential tcl pkg-config -y

# Download redis from their official channel
cd /tmp
curl -O http://download.redis.io/redis-stable.tar.gz
tar xzvf redis-stable.tar.gz
cd redis-stable

# Make and install redis
make
make test
make install

# Configure redis
mkdir /etc/redis
cp /tmp/redis-stable/redis.conf /etc/redis
sed -i "s/supervised on/supervised systemd/" /etc/redis/redis.conf
sed -i "s/dir \.\//dir \/var\/lib\/redis/" /etc/redis/redis.conf

# Add origin for easy access
touch /etc/systemd/system/redis.service
cat >> /etc/systemd/system/redis.service << EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
User=redis
Group=redis
ExecStart=/usr/local/bin/redis-server /etc/redis/redis.conf
ExecStop=/usr/local/bin/redis-cli shutdown
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create user & group for redis
adduser --system --group --no-create-home redis
mkdir /var/lib/redis
chown redis:redis /var/lib/redis
chmod 770 /var/lib/redis

# Start redis service
systemctl start redis

# Enable to start automatically on server boot
sudo systemctl enable redis
