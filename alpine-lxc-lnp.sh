#!/bin/sh
# 自适应Alpine版本 Nginx + PHP8 一键安装脚本 (1G硬盘LXC容器终极优化版)
# 支持Alpine 3.17-3.20+，自动匹配官方源最新PHP8版本
# 新增：三种日志模式可选，彻底解决磁盘空间不足问题
# 全程磁盘占用<80MB

echo "============================================="
echo "  自适应Alpine版本 Nginx + PHP8 一键安装脚本"
echo "  1G硬盘LXC容器终极优化版 - 日志零占用"
echo "============================================="
echo ""

# 日志模式选择 (请根据需要修改)
# 0 = 完全禁用所有日志 (推荐，最省空间)
# 1 = 智能极简轮转 (总大小<10MB，保留1天)
# 2 = 内存日志 (tmpfs，重启自动清空)
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
echo "✅ 日志模式: $(case $LOG_MODE in 0) echo "完全禁用"; 1) echo "智能轮转"; 2) echo "内存日志"; esac)"
echo ""

# 先清理之前失败的安装残留和旧日志
echo "🧹 清理之前的安装残留和旧日志..."
rc-service nginx stop >/dev/null 2>&1
rc-update del nginx default >/dev/null 2>&1
rc-service php-fpm${PHP_VERSION} stop >/dev/null 2>&1
rc-update del php-fpm${PHP_VERSION} default >/dev/null 2>&1
rc-service syslog stop >/dev/null 2>&1
rc-update del syslog default >/dev/null 2>&1
apk del --purge nginx nginx-openrc php8* logrotate >/dev/null 2>&1
rm -rf /etc/php8* /etc/nginx/http.d/default.conf /var/www/html/index.php
rm -rf /var/log/* /tmp/*

# 更新系统
echo "🔄 更新系统软件包索引..."
apk update --quiet

# 安装Nginx
echo "📦 安装Nginx..."
apk add --no-cache nginx nginx-openrc

# 安装PHP及常用扩展 (自动适配版本)
echo "📦 安装PHP8.${PHP_VERSION#8}及常用扩展..."
apk add --no-cache \
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

# 配置日志模式
echo "⚙️ 配置日志模式..."
case $LOG_MODE in
    0)
        # 方案一：完全禁用所有日志
        echo "  → 完全禁用所有日志文件"
        
        # 禁用Nginx日志
        sed -i 's/^error_log .*/error_log \/dev\/null;/' /etc/nginx/nginx.conf
        sed -i 's/^access_log .*/access_log off;/' /etc/nginx/nginx.conf
        
        # 禁用PHP日志
        sed -i 's/^error_log = .*/error_log = \/dev\/null/' /etc/php${PHP_VERSION}/php.ini
        sed -i 's/^;php_admin_value\[error_log\] = .*/php_admin_value\[error_log\] = \/dev\/null/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
        sed -i 's/^access.log = .*/access.log = \/dev\/null/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
        
        # 禁用系统日志服务
        rc-update del syslog default >/dev/null 2>&1
        rc-service syslog stop >/dev/null 2>&1
        ;;
        
    1)
        # 方案二：智能极简日志轮转
        echo "  → 配置智能极简日志轮转 (总大小<10MB)"
        
        apk add --no-cache logrotate
        
        # 配置Nginx日志轮转
        cat > /etc/logrotate.d/nginx << 'EOF'
/var/log/nginx/*.log {
    daily
    rotate 1
    size 5M
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        rc-service nginx reopen >/dev/null 2>&1
    endscript
}
EOF

        # 配置PHP日志轮转
        cat > /etc/logrotate.d/php${PHP_VERSION} << EOF
/var/log/php${PHP_VERSION}/*.log {
    daily
    rotate 1
    size 5M
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        rc-service php-fpm${PHP_VERSION} reload >/dev/null 2>&1
    endscript
}
EOF

        # 配置系统日志轮转
        cat > /etc/logrotate.d/syslog << 'EOF'
/var/log/messages /var/log/secure {
    daily
    rotate 1
    size 1M
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        rc-service syslog reload >/dev/null 2>&1
    endscript
}
EOF

        # 设置logrotate每小时运行一次
        echo "0 * * * * /usr/sbin/logrotate /etc/logrotate.conf" > /etc/crontabs/root
        rc-update add crond default
        rc-service crond start
        ;;
        
    2)
        # 方案三：内存日志 (tmpfs)
        echo "  → 配置内存日志 (重启自动清空)"
        
        # 将/var/log挂载为tmpfs
        echo "tmpfs /var/log tmpfs defaults,noatime,size=10M 0 0" >> /etc/fstab
        mount /var/log
        
        # 创建必要的日志目录
        mkdir -p /var/log/nginx /var/log/php${PHP_VERSION}
        chown nginx:nginx /var/log/nginx
        chown root:root /var/log/php${PHP_VERSION}
        ;;
esac

# 配置PHP-FPM
echo "⚙️ 配置PHP-FPM..."
sed -i 's/^listen = 127.0.0.1:9000/listen = \/run\/php-fpm'"${PHP_VERSION}"'.sock/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^;listen.owner = nobody/listen.owner = nginx/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^;listen.group = nobody/listen.group = nginx/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^;listen.mode = 0660/listen.mode = 0660/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf

# 配置Nginx支持PHP
echo "⚙️ 配置Nginx支持PHP..."
cat > /etc/nginx/http.d/default.conf << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

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
        .disk { margin-top: 20px; }
    </style>
</head>
<body>
    <div class="success">✅ Nginx + PHP8 安装成功！</div>
    
    <div class="info">
        <h3>服务器信息</h3>
        <p><strong>操作系统：</strong><?php echo php_uname('s') . ' ' . php_uname('r') . ' (Alpine ' . file_get_contents('/etc/alpine-release') . ')'; ?></p>
        <p><strong>PHP版本：</strong><?php echo phpversion(); ?></p>
        <p><strong>Nginx版本：</strong><?php echo $_SERVER['SERVER_SOFTWARE']; ?></p>
        <p><strong>网站根目录：</strong>/var/www/html</p>
        <p><strong>服务器时间：</strong><?php echo date('Y-m-d H:i:s'); ?></p>
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

echo ""
echo "============================================="
echo "🎉 安装完成！"
echo "============================================="
echo ""
echo "📌 网站根目录：/var/www/html"
echo "🌐 IP访问地址：http://$CONTAINER_IP"
echo ""
echo "📝 日志配置说明："
case $LOG_MODE in
    0) echo "  ✅ 完全禁用所有日志，磁盘零占用" ;;
    1) echo "  ✅ 智能日志轮转，总大小限制在10MB以内" ;;
    2) echo "  ✅ 内存日志模式，容器重启自动清空" ;;
esac
echo ""
echo "🔧 常用命令："
echo "  - 重启Nginx：rc-service nginx restart"
echo "  - 重启PHP-FPM：rc-service php-fpm${PHP_VERSION} restart"
echo "  - 查看磁盘使用：df -h"
echo "============================================="
