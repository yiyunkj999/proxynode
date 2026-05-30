#!/bin/sh
# 自适应Alpine版本的Nginx + PHP8 一键安装脚本 (LXC容器专用)
# 支持Alpine 3.17-3.20+，自动匹配官方源最新PHP8版本
# 磁盘占用<100MB，专为1G硬盘LXC容器云优化
# 已增加：完全禁用所有日志 + 自动根据内存设置PHP-FPM进程数

echo "============================================="
echo "  自适应Alpine版本 Nginx + PHP8 一键安装脚本"
echo "  专为1G硬盘LXC容器云优化 | 已禁用所有日志"
echo "============================================="
echo ""

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
        echo "⚠️  自动使用最新稳定版PHP8.3 (如安装失败请升级Alpine系统)"
        PHP_VERSION="83"
        ;;
esac

echo "✅ 检测到Alpine版本: $ALPINE_VERSION"
echo "✅ 将安装PHP版本: 8.${PHP_VERSION#8}"
echo ""

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

# 配置PHP-FPM基础设置 (自动适配版本路径)
echo "⚙️ 配置PHP-FPM基础设置..."
sed -i 's/^listen = 127.0.0.1:9000/listen = \/run\/php-fpm'"${PHP_VERSION}"'.sock/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^;listen.owner = nobody/listen.owner = nginx/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^;listen.group = nobody/listen.group = nginx/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^;listen.mode = 0660/listen.mode = 0660/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf

# 自动根据系统内存设置PHP-FPM进程数
echo "⚙️ 自动根据系统内存设置PHP-FPM进程数..."
# 获取系统总内存(MB)
TOTAL_MEM=$(free -m | awk '/Mem:/ {print $2}')
# 系统预留内存(MB) - 给系统和Nginx使用
RESERVED_MEM=150
# 每个PHP进程预估内存占用(MB) - Alpine下PHP8平均约25-30MB，保守取30MB
PHP_PROCESS_MEM=30

# 计算可用内存
AVAILABLE_MEM=$((TOTAL_MEM - RESERVED_MEM))
if [ $AVAILABLE_MEM -lt 0 ]; then
    AVAILABLE_MEM=0
fi

# 计算最大子进程数，最低为5
MAX_CHILDREN=$((AVAILABLE_MEM / PHP_PROCESS_MEM))
if [ $MAX_CHILDREN -lt 5 ]; then
    MAX_CHILDREN=5
fi

# 计算其他相关参数
START_SERVERS=$((MAX_CHILDREN / 4))
if [ $START_SERVERS -lt 1 ]; then
    START_SERVERS=1
fi

MIN_SPARE_SERVERS=$START_SERVERS
MAX_SPARE_SERVERS=$((MAX_CHILDREN / 2))
if [ $MAX_SPARE_SERVERS -lt 2 ]; then
    MAX_SPARE_SERVERS=2
fi

echo "✅ 系统总内存: ${TOTAL_MEM}MB"
echo "✅ 预留系统内存: ${RESERVED_MEM}MB"
echo "✅ 每个PHP进程预估: ${PHP_PROCESS_MEM}MB"
echo "✅ 设置pm.max_children: ${MAX_CHILDREN}"
echo "✅ 设置pm.start_servers: ${START_SERVERS}"
echo "✅ 设置pm.min_spare_servers: ${MIN_SPARE_SERVERS}"
echo "✅ 设置pm.max_spare_servers: ${MAX_SPARE_SERVERS}"

# 应用PHP-FPM进程数配置
sed -i "s/^pm.max_children = .*/pm.max_children = ${MAX_CHILDREN}/" /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i "s/^pm.start_servers = .*/pm.start_servers = ${START_SERVERS}/" /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = ${MIN_SPARE_SERVERS}/" /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = ${MAX_SPARE_SERVERS}/" /etc/php${PHP_VERSION}/php-fpm.d/www.conf

# 禁用PHP-FPM日志
echo "🚫 禁用PHP-FPM所有日志..."
sed -i 's/^;error_log = log\/php-fpm.log/error_log = \/dev\/null/' /etc/php${PHP_VERSION}/php-fpm.conf
sed -i 's/^;access.log = log\/\$pool.access.log/access.log = \/dev\/null/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
# 禁用PHP-FPM慢日志
sed -i 's/^;slowlog = log\/\$pool.log.slow/slowlog = \/dev\/null/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf
sed -i 's/^;request_slowlog_timeout = 0/request_slowlog_timeout = 0/' /etc/php${PHP_VERSION}/php-fpm.d/www.conf

# 禁用PHP错误日志和所有日志输出
echo "🚫 禁用PHP所有日志输出..."
sed -i 's/^error_log = \/var\/log\/php'"${PHP_VERSION}"'\/error.log/error_log = \/dev\/null/' /etc/php${PHP_VERSION}/php.ini
sed -i 's/^log_errors = On/log_errors = Off/' /etc/php${PHP_VERSION}/php.ini
sed -i 's/^display_errors = On/display_errors = Off/' /etc/php${PHP_VERSION}/php.ini
sed -i 's/^display_startup_errors = On/display_startup_errors = Off/' /etc/php${PHP_VERSION}/php.ini
sed -i 's/^;log_errors_max_len = 1024/log_errors_max_len = 0/' /etc/php${PHP_VERSION}/php.ini
# 禁用PHP所有错误报告
sed -i 's/^error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = 0/' /etc/php${PHP_VERSION}/php.ini

# 配置Nginx支持PHP (自动适配Unix Socket路径)
echo "⚙️ 配置Nginx支持PHP..."
cat > /etc/nginx/http.d/default.conf << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    # 禁用Nginx访问日志和错误日志
    access_log off;
    error_log /dev/null crit;

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

# 禁用Nginx全局日志
echo "🚫 禁用Nginx全局日志..."
sed -i 's/^error_log \/var\/log\/nginx\/error.log warn;/error_log \/dev\/null crit;/' /etc/nginx/nginx.conf
sed -i '/^http {/a\    access_log off;' /etc/nginx/nginx.conf

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
        <p><strong>操作系统：</strong><?php echo php_uname('s') . ' ' . php_uname('r') . ' (Alpine ' . file_get_contents('/etc/alpine-release') . ')'; ?></p>
        <p><strong>PHP版本：</strong><?php echo phpversion(); ?></p>
        <p><strong>Nginx版本：</strong><?php echo $_SERVER['SERVER_SOFTWARE']; ?></p>
        <p><strong>网站根目录：</strong>/var/www/html</p>
        <p><strong>服务器时间：</strong><?php echo date('Y-m-d H:i:s'); ?></p>
        <p><strong>日志状态：</strong>所有日志已完全禁用</p>
    </div>
    
    <div class="phpinfo">
        <h3>PHP详细信息</h3>
        <?php phpinfo(); ?>
    </div>
</body>
</html>
EOF

chown nginx:nginx /var/www/html/index.php

# 删除所有日志目录并创建空目录防止报错
echo "🧹 删除所有日志文件并创建空目录..."
rm -rf /var/log/nginx/* /var/log/php${PHP_VERSION}/*
mkdir -p /var/log/nginx /var/log/php${PHP_VERSION}
chown nginx:nginx /var/log/nginx
chown nginx:nginx /var/log/php${PHP_VERSION}

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
echo "🚫 所有Nginx和PHP日志已完全禁用"
echo "⚙️ PHP-FPM最大进程数：${MAX_CHILDREN} (自动根据内存计算)"
echo ""
echo "📝 说明："
echo "  - 所有网站文件请放在 /var/www/html 目录下"
echo "  - Nginx配置文件：/etc/nginx/http.d/default.conf"
echo "  - PHP配置文件：/etc/php${PHP_VERSION}/php.ini"
echo "  - PHP-FPM配置文件：/etc/php${PHP_VERSION}/php-fpm.d/www.conf"
echo ""
echo "🔧 常用命令："
echo "  - 重启Nginx：rc-service nginx restart"
echo "  - 重启PHP-FPM：rc-service php-fpm${PHP_VERSION} restart"
echo "============================================="
