sudo yum install -y gcc gcc-c++ git httpd-tools
mkdir -p /home/vagrant/nginx
mkdir -p /home/vagrant/downloads
cd /home/vagrant/downloads
wget https://github.com/vozlt/nginx-module-vts/archive/v0.1.18.tar.gz
tar -xzvf v0.1.18.tar.gz 
wget https://ftp.pcre.org/pub/pcre/pcre-8.44.tar.gz
tar -xzvf pcre-8.44.tar.gz
wget https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz
tar -xzvf openssl-1.0.2u.tar.gz
wget https://nginx.org/download/nginx-1.20.0.tar.gz
tar -xzvf nginx-1.20.0.tar.gz
rm -f *.tar.gz

cd /home/vagrant/downloads/nginx-1.20.0
./configure  --prefix=/home/vagrant/nginx \
    --sbin-path=/home/vagrant/nginx/sbin/nginx \
    --conf-path=/home/vagrant/nginx/conf/nginx.conf \
    --error-log-path=/home/vagrant/nginx/logs/error.log \
    --http-log-path=/home/vagrant/nginx/logs/access.log \
    --pid-path=/home/vagrant/nginx/logs/nginx.pid \
    --user=vagrant \
    --group=vagrant \
    --with-http_ssl_module \
    --with-http_realip_module \
    --without-http_gzip_module \
    --add-dynamic-module=/home/vagrant/downloads/nginx-module-vts-0.1.18 \
    --with-pcre=/home/vagrant/downloads/pcre-8.44 \
    --with-openssl=/home/vagrant/downloads/openssl-1.0.2u 
    
make
make install

sudo bash -c 'cat << EOF > /etc/systemd/system/nginx.service 
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
User=vagrant
Group=vagrant
Type=forking
PIDFile=/home/vagrant/nginx/logs/nginx.pid
ExecStartPre=/home/vagrant/nginx/sbin/nginx -t
ExecStartPre=/usr/bin/chown -R vagrant:vagrant /home/vagrant/nginx
ExecStart=/home/vagrant/nginx/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF'

tar -xzf /vagrant/html.tar.gz -C /home/vagrant/nginx/html --strip-components=1
cat << EOF > /home/vagrant/nginx/conf/nginx.conf
user vagrant;
worker_processes 1;
pid /home/vagrant/nginx/logs/nginx.pid;
load_module /home/vagrant/nginx/modules/ngx_http_vhost_traffic_status_module.so;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    client_header_timeout  3m;
    client_body_timeout    3m;
    send_timeout           3m;
    sendfile         on;
    keepalive_timeout  120;
    vhost_traffic_status_zone;
    include /home/vagrant/nginx/conf/vhosts/backend.conf;
}
EOF
mkdir /home/vagrant/nginx/conf/vhosts
cat << EOF >  /home/vagrant/nginx/conf/vhosts/backend.conf
server {
    listen       192.168.56.10:8080;
    server_name  nginx;

    location / {
            root   html;
            index  index.html index.htm;
        }

    location /pictures/ {
            root   html/resources;
        }
    
    location /status {
        allow   192.168.56.1;
        deny    all;
        vhost_traffic_status_display;
        vhost_traffic_status_display_format html;
    }

    location /admin {
        auth_basic "Admin's Page";
        auth_basic_user_file /home/vagrant/nginx/conf/.htpasswd;
        alias  html;
        index admin.html;
    }

    error_page   404  /404.html;
    location = /404.html {
    root   html;
    }
}
EOF
htpasswd -m -b -c /home/vagrant/nginx/conf/.htpasswd admin nginx
sudo chown -R vagrant /home/vagrant/nginx/
sudo chgrp -R vagrant /home/vagrant/nginx/
sudo systemctl daemon-reload
sudo systemctl enable nginx
sudo systemctl start nginx

