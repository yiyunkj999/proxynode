#!/bin/sh
clear
echo "============================================="
echo "  Alpine LXC 一键安装（已修复FTP 500错误）"
echo "============================================="
sleep 1

# 1. 更新
apk update
apk add --no-cache tzdata

# 2. 安装 Nginx
apk add --no-cache nginx
rc-update add nginx default
service nginx start

# 3. 安装 PHP7.2
apk add --no-cache php7 php7-fpm php7-mbstring php7-session php7-json php7-gd php7-curl php7-opcache php7-zlib php7-dom
rc-update add php-fpm7 default
service php-fpm7 start

# 4. 安装并修复 vsftpd
apk add --no-cache vsftpd

# 关键修复：解决 500 OOPS: child died
echo "seccomp_sandbox=NO" >> /etc/vsftpd.conf

cat > /etc/vsftpd.conf << EOF
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_min_port=40000
pasv_max_port=40100
listen=YES
seccomp_sandbox=NO
EOF

rc-update add vsftpd default
service vsftpd restart

# 5. 网站目录
mkdir -p /var/www/html
chown -R nginx:nginx /var/www/html
chmod -R 755 /var/www/html

# 6. Nginx 配置
cat > /etc/nginx/nginx.conf << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    server {
        listen 80;
        root /var/www/html;
        index index.php index.html;

        location / {
            try_files \$uri \$uri/ /index.php;
        }

        location ~ \.php$ {
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
EOF

# 7. 创建FTP用户（关键权限修复）
adduser -h /var/www/html -s /sbin/nologin -D ftpuser
chmod 755 /var/www/html
echo -e "\n===== 设置 FTP 密码 ====="
passwd ftpuser

# 8. 测试页面
echo "<h1>网站运行正常</h1>" > /var/www/html/index.html
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# 9. 重启所有服务
service nginx restart
service php-fpm7 restart
service vsftpd restart

# 10. 显示信息
IP=$(hostname -i | awk '{print $1}')
clear
echo "============================================="
echo " ✅ 安装完成！FTP 500错误已修复"
echo "============================================="
echo "网站：http://$IP"
echo "PHP：http://$IP/info.php"
echo ""
echo "FTP 信息"
echo "主机：$IP"
echo "端口：21"
echo "用户：ftpuser"
echo "密码：你刚设置的密码"
echo "============================================="
