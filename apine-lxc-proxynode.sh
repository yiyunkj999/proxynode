#!/bin/sh
clear
echo "============================================="
echo "  Alpine LXC 一键安装 Nginx+PHP7.2+FTP+建站  "
echo "============================================="
sleep 1

# 1. 更新源
apk update
apk add --no-cache tzdata

# 2. 安装 Nginx
apk add --no-cache nginx
rc-update add nginx default
service nginx start

# 3. 安装 PHP7.2 (Alpine 官方源)
apk add --no-cache php7 php7-fpm php7-mbstring php7-session php7-json php7-gd php7-curl php7-opcache php7-zlib php7-dom
rc-update add php-fpm7 default
service php-fpm7 start

# 4. 安装 FTP (vsftpd)
apk add --no-cache vsftpd
# 配置FTP
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
EOF
rc-update add vsftpd default
service vsftpd start

# 5. 创建网站目录 + 权限
mkdir -p /var/www/html
chown -R nginx:nginx /var/www/html
chmod -R 755 /var/www/html

# 6. Nginx 配置（IP 直接访问网站）
cat > /etc/nginx/conf.d/default.conf << EOF
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
EOF

# 7. 创建 FTP 用户（只能访问网站，禁止SSH）
adduser -h /var/www/html -s /sbin/nologin -D ftpuser
echo -e "\n===== 设置 FTP 密码 ====="
passwd ftpuser

# 8. 创建测试页面
echo "<h1>我的网站 - 运行正常</h1>" > /var/www/html/index.html
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# 9. 重启服务
service nginx restart
service php-fpm7 restart
service vsftpd restart

# 10. 输出信息
IP=$(hostname -i | awk '{print $1}')
clear
echo "============================================="
echo "              安装完成 ✅"
echo "============================================="
echo "🌍 网站地址：http://$IP"
echo "🔍 PHP测试：http://$IP/info.php"
echo ""
echo "📤 FTP 信息"
echo "主机：$IP"
echo "端口：21"
echo "用户：ftpuser"
echo "密码：你刚设置的密码"
echo "目录：/var/www/html"
echo "============================================="
