# #!/bin/bash
 set -e 
 set -x
user=vagrant

# ◦NGINX should run under user <user>
# ◦build with http_ssl module
# ◦build with http_realip module
# ◦build without http_gzip module
# ◦build with 3rd party module nginx-module-vts (https://github.com/vozlt/nginx-module-vts)
if  ! command -v git &> /dev/null  || ! command -v gcc &> /dev/null  ;then
    echo "git could not be found"
    sudo  yum install -y gcc gcc-c++ git
fi
if [ ! -d "/vagrant/nginx-module-vts" ];then
    git clone git://github.com/vozlt/nginx-module-vts.git /vagrant/nginx-module-vts
    chown vagrant:vagrant /vagrant/nginx-module-vts
fi
# ◦nginx should be compiled with PCRE and OpenSSL
if [ ! -f "/vagrant/pcre.zip" ];then
    wget https://ftp.pcre.org/pub/pcre/pcre-8.45.zip -O /vagrant/pcre.zip
    chown vagrant:vagrant /vagrant/pcre.zip
fi
if [ ! -d "/vagrant/pcre" ];then
    mkdir -p /vagrant/pcre/
    chown vagrant:vagrant /vagrant/pcre
fi
if  ! command -v unzip &> /dev/null ;then
    echo "zip could not be found"
    sudo  yum install -y unzip
fi
if [ -f "/vagrant/pcre.zip" ] &&  [ ! "$(ls -A /vagrant/pcre/)" ];then
    unzip /vagrant/pcre.zip -d/vagrant/pcre
    echo 'extract pcre'
    chown vagrant:vagrant -R /vagrant/pcre
fi

if [ ! -f "/vagrant/openssl.zip" ];then
    wget https://github.com/openssl/openssl/archive/refs/tags/OpenSSL_1_0_2u.zip -O /vagrant/openssl.zip
    chown vagrant:vagrant /vagrant/openssl.zip
fi
if [ ! -d "/vagrant/openssl" ];then
    mkdir -p /vagrant/pcre/
    chown vagrant:vagrant /vagrant/pcre
fi
if [ -f "/vagrant/openssl.zip" ] &&  [ ! "$(ls -A /vagrant/openssl/)" ];then
    unzip /vagrant/openssl.zip -d/vagrant/openssl
    echo 'extract openssl'
    chown vagrant:vagrant -R /vagrant/openssl 
fi

#Download nginx 
if [ ! -f "/vagrant/nginx.tar.gz" ];then
    wget https://nginx.org/download/nginx-1.20.1.tar.gz -O /vagrant/nginx.tar.gz
    chown vagrant:vagrant /vagrant/nginx.tar.gz
fi
if [ ! -d "/vagrant/nginx" ];then
    mkdir -p /vagrant/nginx/
    chown vagrant:vagrant /vagrant/nginx
fi
if [ -f "/vagrant/nginx.tar.gz" ] &&  [ ! "$(ls -A /vagrant/nginx/)" ];then
    tar -xf /vagrant/nginx.tar.gz -C /vagrant/
    cp -dR /vagrant/nginx-1.20.1/* /vagrant/nginx
    rm -rf /vagrant/nginx-1.20.1
    echo 'extract nginx'
    chown vagrant:vagrant -R /vagrant/nginx 
fi 


#2.Create systemd script for NGINX (you can find any or re-use existing from nginx installation from yum repository). 
sudo -i touch /etc/systemd/system/nginx.service
sudo -i chown vagrant:vagrant /etc/systemd/system/nginx.service

sudo -i cat > /etc/systemd/system/nginx.service << 'EOF' 
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
User=vagrant
Group=vagrant
Type=forking
PIDFile=/home/vagrant/nginx/logs/nginx.pid
ExecStartPre=/usr/bin/rm -f /home/vagrant/nginx/logs/nginx.pid
ExecStart=/home/vagrant/nginx/sbin/nginx -c /home/vagrant/nginx/conf/nginx.conf
ExecReload=/home/vagrant/nginx/sbin/nginx -s reload
ExecStop=/home/vagrant/nginx/sbin/nginx -s quit
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF



# 3.Create configuration files with the following conditions:

# Extract files from “html.tar.gz” archive in lecture materials to your “/home/<user>/nginx/html/” folder
if [ ! -d "/home/$user/nginx/html" ];then
    mkdir -p /home/$user/nginx/html
    chown vagrant:vagrant /home/$user/nginx/html
fi
if [ -f "/vagrant/html.tar.gz" ] &&  [ ! "$(ls -A /home/$user/nginx/html)" ];then
    tar -xf /vagrant/html.tar.gz -C /home/$user/nginx/
    echo 'extract'
    chown vagrant:vagrant -R /home/$user/nginx/html
fi

BUILD=$1
echo "$1"
#if [ $1 ];then
cd /vagrant/nginx
sudo ./configure \
 --prefix=/home/vagrant/nginx \
 --sbin-path=/home/vagrant/nginx/sbin/nginx \
 --conf-path=//home/vagrant/nginx/conf/nginx.conf \
 --pid-path=/home/vagrant/nginx/logs/nginx.pid \
 --http-log-path=/home/vagrant/nginx/logs/access.log \
 --user=vagrant \
 --error-log-path=/home/vagrant/nginx/logs/access.log \
 --with-pcre=/vagrant/pcre/pcre-8.45 \
 --with-http_ssl_module \
 --with-http_realip_module \
 --without-http_gzip_module \
 --with-openssl=/vagrant/openssl/openssl-OpenSSL_1_0_2u \
 --add-module=/vagrant/nginx-module-vts
make
make install
echo "Build $1"
#fi

#       Set number of worker processes to 1
#       Set number of connections per worker to 1024
#       NGINX should serve your site on port 8080
#       NGINX should serve your site on node ip address
# <ip-address>:8080 should return “html/index.html” file
# <ip-address>:8080/pictures/* should return files from “html/resources/pictures/*” 
# (e.g. <ip-address>:8080/pictures/01.jpg)
# <ip-address>:8080/status should return status page of nginx-module-vts 3rd party module and should be only available from your workstation’s ip-address
# <ip-address>:8080/admin should return “html/admin.html” file and should be protected by basic authentication with one or more users, one of which should be user “admin” with password “nginx”. User file (hidden) should be in “/home/<user>/nginx/conf/” folder
# server block should be in a separate config file located under “/home/<user>/nginx/conf/vhosts/backend.conf”
# Return custom 404 error page if missed file/page is requested (404.html)

#       To make nginx-module-vts status page to work, add:
#       following directive to http block:
#        vhost_traffic_status_zone; 
#       following directives to “/status” location block
#       vhost_traffic_status_display;
#       vhost_traffic_status_display_format html;
sudo yum install httpd-tools -y
sudo htpasswd -c -b /home/vagrant/nginx/conf/.htpasswd admin nginx
sudo htpasswd  -b /home/vagrant/nginx/conf/.htpasswd user2 nginx
sudo chown vagrant:vagrant /home/vagrant/nginx/conf/.htpasswd
cat > /home/$user/nginx/conf/nginx.conf << "EOF" 
user vagrant;
worker_processes 1;
error_log /home/vagrant/nginx/logs/error.log;
pid /home/vagrant/nginx/logs/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /home/vagrant/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    vhost_traffic_status_zone;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /home/vagrant/nginx/logs/access.log  main;

    sendfile            on;
    # tcp_nopush          on;
    # tcp_nodelay         on;
    keepalive_timeout   65;
    #types_hash_max_size 4096;

    include             /home/vagrant/nginx/conf/mime.types;
    default_type        application/octet-stream;

    include /home/vagrant/nginx/conf/vhost/*.conf;
}
EOF
chown vagrant:vagrant /home/$user/nginx/conf/nginx.conf
if [ ! -d "/home/$user/nginx/conf/vhost" ];then
    mkdir -p /home/$user/nginx/conf/vhost
    chown vagrant:vagrant -R /home/$user/nginx/conf/vhost
fi
sudo -i touch /home/$user/nginx/conf/vhost/backend.conf
sudo -i chown vagrant:vagrant /home/$user/nginx/conf/vhost/backend.conf
cat > /home/$user/nginx/conf/vhost/backend.conf << "EOF" 
server {
        listen       192.168.56.100:8080;
        server_name  192.168.56.100;
        #root         /home/vagrant/nginx/html;
        access_log /home/vagrant/nginx/logs/access.log;

        # Load configuration files for the default server block.
        #include /home/vagrant/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
        location / {
            root /home/vagrant/nginx/html;
            index index.html index.htm;
        }
        # location ~* ^/pictures/.*$ {
        #     return 200 "Hello pictures";
            
        # }
        location /pictures {
            root /home/vagrant/nginx/html/resources;
            try_files $uri =404;
            
        }
        location /admin {
            alias html;
            auth_basic "restricted";
            auth_basic_user_file  /home/vagrant/nginx/conf/.htpasswd;
            index admin.html;
            #try_files $uri =404;
        }
        

        location /status {
            allow   192.168.56.1;
            deny    all;
            vhost_traffic_status_display;
            vhost_traffic_status_display_format html;
        }

    }  
EOF

# 4.Start NGINX
# Use your systemd script to start NGINX
sudo chown -R vagrant:vagrant /home/vagrant/nginx
sudo systemctl daemon-reload
sudo systemctl start nginx
sudo systemctl enable nginx
name=`whoami`
echo "hello from $name"
