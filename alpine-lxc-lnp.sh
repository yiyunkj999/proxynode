#!/bin/sh
# Alpine LXC 轻量一键脚本：Nginx + PHP7.2 + FileBox 文件管理器
# 适用：1G硬盘/小内存LXC容器，IP直接访问

# 1. 更新源并安装依赖
echo "===== 更新系统源并安装基础软件 ====="
sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
apk update && apk upgrade -y
apk add nginx php7 php7-fpm php7-json php7-session php7-opcache php7-mbstring php7-gd php7-curl php7-zip wget unzip curl

# 2. 启动服务并设置开机自启
echo "===== 启动Nginx/PHP7服务 ====="
rc-service nginx start
rc-service php7-fpm start
rc-update add nginx default
rc-update add php7-fpm default

# 3. 配置Nginx (适配PHP7.2，根目录/var/www/html)
echo "===== 配置Nginx ====="
cat > /etc/nginx/conf.d/default.conf << EOF
server {
    listen 80;
    server_name _;
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

# 4. 下载安装 FileBox 轻量文件管理器
echo "===== 安装 FileBox 文件管理器 ====="
rm -rf /var/www/html/*
cd /var/www/html
wget -O filebox.zip https://ghproxy.net/https://raw.githubusercontent.com/filebrowser/filebrowser/master/frontend/dist/index.html
wget -O filebox.php https://ghproxy.net/https://raw.githubusercontent.com/helloxz/filebox/master/filebox.php
mv filebox.php index.php
chown -R nginx:nginx /var/www/html
chmod -R 755 /var/www/html

# 5. 重启服务生效
echo "===== 重启服务完成部署 ====="
rc-service nginx restart
rc-service php7-fpm restart

# 6. 输出访问信息
clear
echo "====================================="
echo "  部署完成！访问地址：http://$(curl -s ip.sb)"
echo "  程序：Nginx + PHP7.2 + FileBox 文件管理器"
echo "  网站目录：/var/www/html"
echo "  适配LXC 1G硬盘/小内存，轻量无压力"
echo "====================================="
