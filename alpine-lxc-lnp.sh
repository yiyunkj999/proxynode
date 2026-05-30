#!/bin/sh
# Alpine Linux Nginx + PHP8 一键安装脚本 (LXC容器专用)
# 适用于Alpine 3.20+，磁盘占用<100MB

echo "============================================="
echo "  Alpine Linux Nginx + PHP8 一键安装脚本"
echo "  专为1G硬盘LXC容器云优化"
echo "============================================="
echo ""

# 更新系统
echo "🔄 更新系统软件包索引..."
apk update --quiet

# 安装Nginx
echo "📦 安装Nginx..."
apk add --no-cache nginx

# 安装PHP8.4及常用扩展 (最新稳定版)
echo "📦 安装PHP8.4及常用扩展..."
apk add --no-cache \
    php84 \
    php84-fpm \
    php84-curl \
    php84-gd \
    php84-mbstring \
    php84-openssl \
    php84-xml \
    php84-zip \
    php84-opcache \
    php84-session

# 配置PHP-FPM
echo "⚙️ 配置PHP-FPM..."
sed -i 's/^listen = 127.0.0.1:9000/listen = \/run\/php-fpm84.sock/' /etc/php84/php-fpm.d/www.conf
sed -i 's/^;listen.owner = nobody/listen.owner = nginx/' /etc/php84/php-fpm.d/www.conf
sed -i 's/^;listen.group = nobody/listen.group = nginx/' /etc/php84/php-fpm.d/www.conf
sed -i 's/^;listen.mode = 0660/listen.mode = 0660/' /etc/php84/php-fpm.d/www.conf

# 配置Nginx支持PHP
echo "⚙️ 配置Nginx支持PHP..."
cat > /etc/nginx/http.d/default.conf << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass unix:/run/php-fpm84.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_hide_header X-Powered-By;
    }

    # 安全配置
    location ~ /\.ht {
        deny all;
    }
}
EOF

# 创建网站目录
echo "📂 创建网站目录..."
mkdir -p /var/www/html
chown -R nginx:nginx /var/www/html
chmod -R 755 /var/www/html

# 创建测试页面
echo "📄 创建PHP测试页面..."
cat > /var/www/html/index.php << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Alpine Nginx + PHP8 测试页面</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .success { color: #28a745; font-size: 24px; font-weight: bold; margin-bottom: 20px; }
        .info { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .phpinfo { margin-top: 30px; }
    </style>
</head>
<body>
    <div class="success">✅ Nginx + PHP8 安装成功！</div>
    
    <div class="info">
        <h3>服务器信息</h3>
        <p><strong>操作系统：</strong><?php echo php_uname('s') . ' ' . php_uname('r'); ?></p>
        <p><strong>PHP版本：</strong><?php echo phpversion(); ?></p>
        <p><strong>Nginx版本：</strong><?php echo $_SERVER['SERVER_SOFTWARE']; ?></p>
        <p><strong>网站根目录：</strong>/var/www/html</p>
        <p><strong>服务器时间：</strong><?php echo date('Y-m-d H:i:s'); ?></p>
    </div>
    
    <div class="phpinfo">
        <h3>PHP详细信息</h3>
        <?php phpinfo(); ?>
    </div>
</body>
</html>
EOF

chown nginx:nginx /var/www/html/index.php

# 启动服务并设置开机自启
echo "🚀 启动Nginx和PHP-FPM服务..."
rc-update add nginx default
rc-update add php-fpm84 default
rc-service nginx start
rc-service php-fpm84 start

# 获取容器IP地址
CONTAINER_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

echo ""
echo "============================================="
echo "🎉 安装完成！"
echo "============================================="
echo ""
echo "📌 网站根目录：/var/www/html"
echo "🌐 IP访问地址：http://$CONTAINER_IP"
echo ""
echo "📝 说明："
echo "  - 所有网站文件请放在 /var/www/html 目录下"
echo "  - Nginx配置文件：/etc/nginx/http.d/default.conf"
echo "  - PHP配置文件：/etc/php84/php.ini"
echo "  - PHP-FPM配置文件：/etc/php84/php-fpm.d/www.conf"
echo ""
echo "🔧 常用命令："
echo "  - 重启Nginx：rc-service nginx restart"
echo "  - 重启PHP-FPM：rc-service php-fpm84 restart"
echo "  - 查看Nginx日志：tail -f /var/log/nginx/error.log"
echo "============================================="
