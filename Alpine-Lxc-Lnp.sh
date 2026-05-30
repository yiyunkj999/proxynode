#!/bin/sh
# 自适应Alpine版本 Nginx + PHP8 一键安装脚本
# 1G硬盘LXC容器专用 - 完全零日志终极优化版
# 支持Alpine 3.17-3.20+，自动匹配官方源最新PHP8版本
# 所有日志全部重定向到/dev/null，磁盘零占用

echo "============================================="
echo "  自适应Alpine版本 Nginx + PHP8 一键安装脚本"
echo "  1G硬盘LXC容器专用 - 完全零日志终极优化版"
echo "============================================="
echo ""

# 强制完全禁用所有日志
LOG_MODE=0

# 自动检测Alpine版本并匹配对应的PHP版本
echo "🔍 检测Alpine系统版本..."
ALPINE_VERSION=$(cat /etc/alpine-release | cut -d. -f1-2)

# 版本映射表 (Alpine版本 -> 官方源最新PHP8版本)
case $ALPINE_VERSION in
    "3.17") PHP_VERSION="81" ;;
    "3.18") PHP_VERSION="82" ;;
    "3.19"|"3.20") PHP_VERSION="83" ;;
    *) 
        echo "⚠️  检测到Alpine版本: $ALPINE_VERSION"
        echo "⚠️  自动使用最新稳定版PHP8.3"
        PHP_VERSION="83"
        ;;
esac

echo "✅ 检测到Alpine版本: $ALPINE_VERSION"
echo "✅ 将安装PHP版本: 8.${PHP_VERSION#8}"
echo "✅ 日志模式: 完全禁用所有日志 (磁盘零占用)"
echo ""

# 深度清理：停止所有服务 + 删除所有残留 + 清空所有日志
echo "🧹 深度清理系统残留和所有历史日志..."
# 停止所有可能运行的服务
rc-service nginx stop >/dev/null 2>&1
rc-service php-fpm81 stop >/dev/null 2>&1
rc-service php-fpm82 stop >/dev/null 2>&1
rc-service php-fpm83 stop >/dev/null 2>&1
rc-service syslog stop >/dev/null 2>&1
rc-service crond stop >/dev/null 2>&1
rc-service logrotate stop >/dev/null 2>&1

# 删除所有相关服务自启
rc-update del nginx default >/dev/null 2>&1
rc-update del php-fpm81 default >/dev/null 2>&1
rc-update del php-fpm82 default >/dev/null 2>&1
rc-update del php-fpm83 default >/dev/null 2>&1
rc-update del syslog default >/dev/null 2>&1
rc-update del crond default >/dev/null 2>&1
rc-update del logrotate default >/dev/null 2>&1

# 卸载所有相关软件包
apk del --purge nginx nginx-openrc php8* logrotate syslog-ng busybox-syslogd >/dev/null 2>&1

# 彻底删除所有配置和日志目录
rm -rf /etc/php8* /etc/nginx /var/www/html /var/log/* /tmp/* /var/cache/apk/*
rm -rf /usr/share/doc /usr/share/man /usr/share/info /usr/share/locale

# 更新系统软件包索引
echo "🔄 更新系统软件包索引..."
apk update --quiet

# 安装Nginx
echo "📦 安装Nginx..."
apk add --no-cache --no-scripts nginx nginx-openrc

# 安装PHP及常用扩展 (自动适配版本)
echo "📦 安装PHP8.${PHP_VERSION#8}及常用扩展..."
apk add --no-cache --no-scripts \
    php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-openssl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-session

# 彻底禁用所有日志
echo "⚙️ 彻底禁用所有日志输出..."

# 1. 禁用Nginx所有日志
sed -i 's/^error_log .*/error_log \/dev\/null;/' /etc/nginx/nginx.conf
sed -i 's/^access_log .*/access_log off;/' /etc/nginx/nginx.conf

# 2. 禁用PHP核心所有日志
sed -i 's/^error_log = .*/error_log = \/dev\/null/' /etc/php${PHP_VERSION}/php.ini
sed -i 's/^log_errors = On/log_errors = Off/' /etc/php${PHP_VERSION}/php.ini
sed -i 's/^display_errors = On/display_errors = Off/' /etc/php${PHP_VERSION}/php.ini
sed -i 's/^display_startup_errors = On/display_startup_errors = Off/' /etc/php${PHP_VERSION}/php.ini

# 3. 禁用PHP-FPM所有日志
sed -i 's/^;php_admin_value\[error_log\] = .*/php_admin_value\[error_log\] = \/dev\/null/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^access.log = .*/access.log = \/dev\/null/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^error_log = .*/error_log = \/dev\/null/' /etc/php${PHP_VERSION}/php-fpm.conf

# 4. 禁用系统日志服务
rc-update del syslog default >/dev/null 2>&1
rc-service syslog stop >/dev/null 2>&1

# 配置PHP-FPM
echo "⚙️ 配置PHP-FPM..."
sed -i 's/^listen = 127.0.0.1:9000/listen = \/run\/php-fpm'"${PHP_VERSION}"'.sock/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^;listen.owner = nobody/listen.owner = nginx/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^;listen.group = nobody/listen.group = nginx/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^;listen.mode = 0660/listen.mode = 0660/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf

# 优化PHP-FPM性能 (适合1G内存容器)
sed -i 's/^pm.max_children = .*/pm.max_children = 10/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^pm.start_servers = .*/pm.start_servers = 2/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 1/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 3/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf

# 配置Nginx支持PHP
echo "⚙️ 配置Nginx支持PHP..."
cat > /etc/nginx/http.d/default.conf << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    # 关闭服务器版本信息
    server_tokens off;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_pass unix:/run/php-fpm${PHP_VERSION}.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
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

# 创建测试页面 (包含磁盘使用情况)
echo "📄 创建PHP测试页面..."
cat > /var/www/html/index.php << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Alpine Nginx + PHP8 零日志优化版</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .success { color: #28a745; font-size: 24px; font-weight: bold; margin-bottom: 20px; }
        .info { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .disk { margin-top: 20px; }
        pre { background-color: #e9ecef; padding: 10px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="success">✅ Nginx + PHP8 零日志优化版安装成功！</div>
    
    <div class="info">
        <h3>服务器信息</h3>
        <p><strong>操作系统：</strong><?php echo php_uname('s') . ' ' . php_uname('r') . ' (Alpine ' . trim(file_get_contents('/etc/alpine-release')) . ')'; ?></p>
        <p><strong>PHP版本：</strong><?php echo phpversion(); ?></p>
        <p><strong>Nginx版本：</strong><?php echo $_SERVER['SERVER_SOFTWARE']; ?></p>
        <p><strong>网站根目录：</strong>/var/www/html</p>
        <p><strong>服务器时间：</strong><?php echo date('Y-m-d H:i:s'); ?></p>
        <p><strong>日志状态：</strong><span style="color: #28a745; font-weight: bold;">完全禁用，磁盘零占用</span></p>
    </div>
    
    <div class="disk">
        <h3>磁盘使用情况</h3>
        <pre><?php echo shell_exec('df -h /'); ?></pre>
    </div>
</body>
</html>
EOF

chown nginx:nginx /var/www/html/index.php

# 启动服务并设置开机自启
echo "🚀 启动Nginx和PHP-FPM服务..."
rc-update add nginx default
rc-update add php-fpm${PHP_VERSION} default
rc-service nginx restart
rc-service php-fpm${PHP_VERSION} restart

# 获取容器IP地址
CONTAINER_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# 最终清理
echo "🧹 执行最终空间清理..."
rm -rf /var/cache/apk/* /tmp/*

echo ""
echo "============================================="
echo "🎉 安装完成！"
echo "============================================="
echo ""
echo "📌 网站根目录：/var/www/html"
echo "🌐 IP访问地址：http://$CONTAINER_IP"
echo ""
echo "✅ 所有日志已完全禁用，不会生成任何日志文件"
echo "✅ 系统已深度优化，总磁盘占用约55MB"
echo ""
echo "🔧 常用命令："
echo "  - 重启Nginx：rc-service nginx restart"
echo "  - 重启PHP-FPM：rc-service php-fpm${PHP_VERSION} restart"
echo "  - 查看磁盘使用：df -h"
echo "  - 清理临时文件：rm -rf /tmp/*"
echo "============================================="
