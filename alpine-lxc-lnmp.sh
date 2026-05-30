#!/bin/sh
# Alpine Linux LXC 一键安装 Nginx + PHP7 + FileBox 文件管理器
# 专为1G硬盘容器优化，全程占用<100MB

echo "============================================="
echo "Alpine LXC Nginx+PHP7+FileBox 一键安装脚本"
echo "============================================="

# 更新软件包索引
echo "正在更新软件包索引..."
apk update --no-cache

# 安装必要软件包
echo "正在安装 Nginx 和 PHP7..."
apk add --no-cache \
    nginx \
    php7 \
    php7-fpm \
    php7-json \
    php7-phar \
    php7-iconv \
    php7-openssl \
    php7-mbstring \
    php7-session \
    php7-dom \
    php7-zip \
    php7-curl \
    php7-gd \
    curl \
    ca-certificates

# 创建网站根目录
echo "正在创建网站根目录..."
mkdir -p /var/www/html
chown -R nginx:nginx /var/www/html

# 配置 PHP-FPM
echo "正在配置 PHP-FPM..."
sed -i 's|;listen.owner = nobody|listen.owner = nginx|' /etc/php7/php-fpm.d/www.conf
sed -i 's|;listen.group = nobody|listen.group = nginx|' /etc/php7/php-fpm.d/www.conf
sed -i 's|user = nobody|user = nginx|' /etc/php7/php-fpm.d/www.conf
sed -i 's|group = nobody|group = nginx|' /etc/php7/php-fpm.d/www.conf
sed -i 's|;date.timezone =|date.timezone = Asia/Shanghai|' /etc/php7/php.ini

# 配置 Nginx
echo "正在配置 Nginx..."
cat > /etc/nginx/http.d/default.conf << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;
    
    # 支持大文件上传（最大100MB）
    client_max_body_size 100M;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm7.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_hide_header X-Powered-By;
    }
    
    # 安全配置：隐藏敏感文件
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# 下载 FileBox 文件管理器
echo "正在下载 FileBox 文件管理器..."
curl -L -o /var/www/html/index.php https://raw.githubusercontent.com/jooies/filebox/master/filebox.php

# 设置文件权限
echo "正在设置文件权限..."
chown -R nginx:nginx /var/www/html
chmod -R 755 /var/www/html

# 启动服务并设置开机自启
echo "正在启动服务..."
rc-update add nginx default
rc-update add php-fpm7 default
rc-service php-fpm7 start
rc-service nginx start

# 获取容器IP地址
IP_ADDRESS=$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

echo "============================================="
echo "安装完成！"
echo "============================================="
echo "访问地址: http://$IP_ADDRESS"
echo "默认用户名: filebox"
echo "默认密码: filebox"
echo "============================================="
echo "重要提示："
echo "1. 首次登录后请立即修改密码"
echo "2. 建议将index.php重命名为不易猜测的名称"
echo "3. 如需支持更大文件上传，请修改Nginx配置中的client_max_body_size"
echo "============================================="
