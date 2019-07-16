#tracker
yum -y install make cmake gcc gcc-c++ openssl-devel perl-devel

unzip

cd libfastcommon-master
./make.sh
./make.sh install

cd fastdfs-master
./make.sh
./make.sh install

mkdir -p /data/fastdfs/tracker
cp /etc/fdfs/tracker.conf.sample /etc/fdfs/tracker.conf
vi /etc/fdfs/tracker.conf
base_path=/data/fastdfs/tracker

/etc/init.d/fdfs_trackerd start
systemctl status fdfs_trackerd
systemctl enable fdfs_trackerd
ll /data/fastdfs/tracker


#storage
yum -y install make cmake gcc gcc-c++ openssl-devel perl-devel

unzip

cd libfastcommon-master
./make.sh
./make.sh install

cd fastdfs-master
./make.sh
./make.sh install

mkdir -p /data/fastdfs/storage
cp /etc/fdfs/storage.conf.sample /etc/fdfs/storage.conf
vi /etc/fdfs/storage.conf
#group_name=group1 or group2
base_path=/data/fastdfs/storage
store_path0=/data/fastdfs/storage
tracker_server=10.1.70.91:22122
tracker_server=10.1.70.92:22122


/etc/init.d/fdfs_storaged start
systemctl status fdfs_storaged
systemctl enable fdfs_storaged
ll /data/fastdfs/storage

#查看Storage和Tracker是否在通信：
fdfs_monitor /etc/fdfs/storage.conf


#tracker_client
cp /etc/fdfs/client.conf.sample /etc/fdfs/client.conf
vi /etc/fdfs/client.conf
base_path=/data/fastdfs/client
tracker_server=10.1.70.91:22122
tracker_server=10.1.70.92:22122

fdfs_upload_file /etc/fdfs/client.conf /tmp/test.jpg


#nginx
cd nginx-1.16.0
./configure --prefix=/usr/local/nginx --add-module=../fastdfs-nginx-module-master/src
make & make install


#fastdfs-nginx-module
cp fastdfs-nginx-module-master/src/mod_fastdfs.conf /etc/fdfs
vi /etc/fdfs/mod_fastdfs.conf
base_path=/data/fastdfs
tracker_server=10.1.70.91:22122
tracker_server=10.1.70.92:22122
#group_name=group1 or group2
url_have_group_name = true
store_path0=/data/fastdfs/storage
group_count = 2
[group1]
group_name=group1
storage_server_port=23000
store_path_count=1
store_path0=/data/fastdfs/storage

[group2]
group_name=group2
storage_server_port=23000
store_path_count=1
store_path0=/data/fastdfs/storage


#cp /usr/lib64/libfdfsclient.so /usr/lib/ 
cp fastdfs-master/conf/http.conf fastdfs-master/conf/mime.types /etc/fdfs/








##storage-nginx.conf
#user  nobody;
worker_processes  4;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    server {
        listen       8888;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        #location / {
        #    root   html;
        #    index  index.html index.htm;
        #}

        location ~/group([1-9])/M00 {
              ngx_fastdfs_module;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \.php$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        #location ~ \.php$ {
        #    root           html;
        #    fastcgi_pass   127.0.0.1:9000;
        #    fastcgi_index  index.php;
        #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
        #    include        fastcgi_params;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #    deny  all;
        #}
    }


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}

}




##tracker-nginx.conf
#user  nobody;
worker_processes  4;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;
    #设置group1的服务器
    upstream fastdfs_group1 {
        server 10.1.70.93:8888 weight=1 max_fails=2 fail_timeout=30s;
        server 10.1.70.94:8888 weight=1 max_fails=2 fail_timeout=30s;
    }
    #设置group2的服务器
    upstream fastdfs_group2 {
        server 10.1.70.95:8888 weight=1 max_fails=2 fail_timeout=30s;
        server 10.1.70.96:8888 weight=1 max_fails=2 fail_timeout=30s;
    }
    server {
        listen       10086;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        #location / {
        #    root   html;
        #    index  index.html index.htm;
        #}
        #设置group1的负载均衡参数
        location /group1/M00 {
        proxy_pass http://fastdfs_group1;
        }

        #设置group2的负载均衡参数
        location /group2/M00 {
        proxy_pass http://fastdfs_group2;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \.php$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        #location ~ \.php$ {
        #    root           html;
        #    fastcgi_pass   127.0.0.1:9000;
        #    fastcgi_index  index.php;
        #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
        #    include        fastcgi_params;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #    deny  all;
        #}
    }


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}

}




##nginx.conf
#################fastdfs begin#################
upstream fastdfs {
        server 10.1.70.91:10086 weight=1 fail_timeout=20s;
      	server 10.1.70.92:10086 weight=1 fail_timeout=20s; 
    }
    server {
        listen 12580;
        server_name 10.1.20.90;
        location / {
            proxy_pass http://fastdfs;
            error_page   500 502 503 504  /50x.html;
            location = /50x.html {
            root   html;
            }
        }
    }
##################fastdfs end##################