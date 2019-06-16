#!/bin/bash

# Make sure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root!" 
   exit 1
fi

# Set required temparary variables to use during the script
USER='ubuntu'
WEB_USER='www-data'
APP_NAME='laravel'
NGINX_CONFIG='/etc/nginx/nginx.conf'
NGINX_VIRTUALHOST_FILE='/etc/nginx/sites-enabled/$APP_NAME'
WEB_ROOT='/var/www/html/public'
CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
ULIMIT=$(ulimit -n)
WORKER_LIMIT=$((ULIMIT-100))

# Update Package Lists
apt-get update

# Install add-apt-repository dependencies
apt-get install software-properties-common -y
apt-get install python-software-properties -y

# Add  PHP repositories
LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y

# Update Package Lists
apt-get update -y

# Install nginx 
apt-get -y install nginx

# Install php packages
apt-get -y install  php7.2 php7.2-mysql php7.2-fpm php7.2-mbstring php7.2-xml php7.2-curl 

# Install mysql client
apt-get -y install mysql-client

# Install zip and unzip
apt-get -y install  unzip zip 

# Remove default nginx site config file
rm -f /etc/nginx/sites-enabled/default

# Create a new default nginx mainconfig file
cat > $NGINX_CONFIG << EOF
# Defines the number of worker processes where a worker process here refers to a single-threaded nginx process. 
# A thumb rule to start with is setting this value equal to number of CPU cores the running server has
# You can get this numeric value using `grep -c ^processor /proc/cpuinfo` for linux servers

worker_processes $CPU_CORES;
worker_rlimit_nofile $WORKER_LIMIT;

# User who will be running nginx worker processes processes 
user $WEB_USER;

events {

        # This is number of simultaneuos connections a worker process can have. 
        # Setting this number a very high value will not be helpful as this can not exceed the max open files limit on the server
        # You can check the max open file limit on linux using `ulimit -n`
        # However that limit can be modified(overridden) by worker_rlimit_nofile directive below
        worker_connections $WORKER_LIMIT;
}

http {
    
        # Allows to transfer data from a file descriptor to another directly in kernel space.  
        # Saves resources by following `zero copy` (which referrs to writing directly the kernel buffer from the block device memory through direct memory access DMA).
        sendfile on;

        # Limits the the amount of data that can be transferred in a single sendfile() call. After setting this nginx will not send the entire file together, but will chunk it by 512‑KB pieces.
        sendfile_max_chunk 512k;

        # Optimizes the amount of data sent at once.
        tcp_nopush on;

        # Forces a socket to send the data in its buffer, whatever the packet size.
        # Avoids network congestion and optimizes the delivery sending the data as soon as it's available.
        tcp_nodelay on;

        # Sets a timeout during which a keep-alive client connection will stay open on the server side.
        keepalive_timeout 65s;

        # Sets the maximum number of requests that can be served through one keep-alive connection. After the maximum number of requests are made, the connection is closed.
        keepalive_requests 1000;

        # Avoids emitting nginx version on error pages and in the “Server” response header field
        server_tokens off;

        # Clears the specified output headers. This avoids nginx information apearing on the respose headers visible in the browser.
        more_clear_headers 'Server';
        more_clear_headers 'X-Powered-By';

        # Sets buffer size for reading client request body.
        client_body_buffer_size 10K;

        # Sets buffer size for reading client request header.
        client_header_buffer_size 1k;

        # Sets the maximum allowed size of the client request body, specified in the “Content-Length” request header field. # If it exceeds gives 413 error.
        client_max_body_size 50M;

        # Below are timeout directives. Make sure these directives do not terminate your usual average load times.
        # However setting it to a too large value is not an efficient way as it keeps the process resources in waiting state.
        # Defines a timeout for reading client request body.
        client_body_timeout 60s;

        # Defines a timeout for reading client request header.
        client_header_timeout 60s;

        # Sets a timeout for transmitting a response to the client. 
        send_timeout 60s;

        # Setting defaul and allowed MIME types
        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        
        # Log settings
        # `buffer=64k flush=5m` -> Logs only when total buffered log of of 64kb of 5 mins have passed since last log write
        access_log /var/log/nginx/access.log combined  buffer=64k flush=5m;

        # Error Log
        error_log /var/log/nginx/error.log;

        # Gzip Settings
        gzip             on;
        gzip_min_length  1000;
        gzip_proxied     expired no-cache no-store private auth;
        gzip_types       text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
        gzip_vary on;

        # The higher value of `gzip_comp_level` is set(max 9), more memory is used to compress.
        gzip_comp_level  3;

        # Including virtual host configs
        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
}
EOF


# Create a new default nginx site virtualhost config file
cat > $NGINX_VIRTUALHOST_FILE << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;
    root $WEB_ROOT;
    index index.php index.html index.htm;
    server_name localhost;
    charset   utf-8;
    gzip on;
    gzip_vary on;
    gzip_disable "msie6";
    gzip_comp_level 6;
    gzip_min_length 1100;
    gzip_buffers 16 8k;
    gzip_proxied any;
    gzip_types
        text/plain
        text/css
        text/js
        text/xml
        text/javascript
        application/javascript
        application/x-javascript
        application/json
        application/xml
        application/xml+rss;
location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
location ~ \.php\$ {
        try_files \$uri /index.php =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php7.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
location ~* \.(?:jpg|jpeg|gif|png|ico|cur|gz|svg|svgz|mp4|ogg|ogv|webm|htc|svg|woff|woff2|ttf)\$ {
      expires 1M;
      access_log off;
      add_header Cache-Control "public";
    }
location ~* \.(?:css|js)\$ {
      expires 7d;
      access_log off;
      add_header Cache-Control "public";
    }
location ~ /\.ht {
        deny  all;
    }
}
EOF

# Install composer globally
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Create public directory
mkdir -p $WEB_ROOT

# Create a test index.php file
cat > $WEB_ROOT/index.php << EOF
<?php 
echo 'Its Working';
EOF

# Restart nginx
service nginx restart

# Restart php fpm
service php7.2-fpm restart

# Add user to www-data group
usermod -a -G $WEB_USER $USER
su - $USER
id -g

# Add nice profile prompt to show current git branch
cat >> /home/$USER/.profile << EOF
parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
export PS1="\u@\h \[\033[32m\]\w\[\033[33m\]\$(parse_git_branch)\[\033[00m\] $ "
EOF

# Set up git config
git config --global user.name "$APP_NAME Server"
git config --global user.email "noreply@$APP_NAME.com"
git config --global core.fileMode false
git config --global core.autocrlf false

# Create The Server SSH Key
ssh-keygen -f /home/$USER/.ssh/id_rsa -t rsa -N ''

# Copy Github And Bitbucket Public Keys Into Known Hosts File
ssh-keyscan -H github.com >> /home/$USER/.ssh/known_hosts
ssh-keyscan -H bitbucket.org >> /home/$USER/.ssh/known_hosts

echo 'This is the public access-key to put in git or bitbucket : '
echo '---------------------------------------'
cat /home/$USER/.ssh/id_rsa.pub
echo '---------------------------------------'
