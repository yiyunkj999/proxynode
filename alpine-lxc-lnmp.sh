#!/bin/sh
# 一键部署：Alpine + Nginx + PHP7.2 + FileBox 文件管理器 (LXC容器专用)
# 执行完成后，直接访问容器IP即可使用

# 1. 更新系统并安装基础工具
echo "===== 更新系统并安装依赖 ====="
apk update && apk upgrade -y
apk add wget curl

# 2. 安装Nginx + PHP7.2 + 必备扩展
echo "===== 安装Nginx + PHP7.2 环境 ====="
apk add nginx php7 php7-fpm php7-mbstring php7-openssl php7-json php7-session php7-fileinfo php7-gd php7-zip

# 3. 写入Nginx核心配置
echo "===== 配置Nginx支持PHP ====="
cat > /etc/nginx/conf.d/default.conf << EOF
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php index.html;
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    location ~ /\.ht {
        deny all;
    }
}
EOF

# 4. 部署FileBox单文件管理器
echo "===== 部署FileBox文件管理器 ====="
rm -rf /var/www/html/*
wget https://raw.githubusercontent.com/hncboy/FileBox/master/index.php -O /var/www/html/index.php
chown -R nginx:nginx /var/www/html

# 5. 启动服务并设置开机自启
echo "===== 启动服务并配置开机自启 ====="
rc-service nginx restart
rc-service php7-fpm restart
rc-update add nginx default
rc-update add php7-fpm default

# 6. 完成提示
echo -e "\n====================================="
echo "✅ 部署完成！"
echo "🌐 访问地址：http://$(hostname -I | cut -d' ' -f1)"
echo "📁 功能：文件上传/下载/编辑/管理"
echo "🔒 安全建议：进入页面右上角设置密码"
echo "=====================================\n"
