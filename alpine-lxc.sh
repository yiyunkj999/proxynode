#!/bin/sh
# Alpine 3.20 LXC 修复版一键脚本：Nginx + PHP8.2 + FileBox 文件管理器
# 适配1G硬盘/小内存，无冗余依赖，IP直接访问

clear
echo "===== 开始部署环境 ====="

# 1. 替换国内源 + 更新系统（修复apk -y错误）
sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
apk update
apk upgrade  # Alpine apk无-y参数，直接执行即可

# 2. 安装Nginx + PHP8.2（Alpine3.20仅支持PHP8，废弃PHP7）
apk add nginx php82 php82-fpm php82-session php82-mbstring php82-gd php82-curl php82-zip wget unzip curl

# 3. 启动服务 + 开机自启
rc-service nginx start
rc-service php82-fpm start
rc-update add nginx default
rc-update add php82-fpm default

# 4. 配置Nginx（适配PHP8.2）
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

# 5. 安装FileBox单文件管理器（无数据库，100%适配1G硬盘）
rm -rf /var/www/html/*
cd /var/www/html
wget -O index.php https://ghproxy.net/https://raw.githubusercontent.com/helloxz/filebox/master/filebox.php
chown -R nginx:nginx /var/www/html
chmod -R 755 /var/www/html

# 6. 重启服务生效
rc-service nginx restart
rc-service php82-fpm restart

# 7. 输出访问信息
clear
echo "====================================="
echo " ✅ 部署完成！"
echo " 🌐 访问地址：http://$(curl -s ip.sb)"
echo " 📦 环境：Nginx + PHP8.2 + FileBox"
echo " 📂 网站目录：/var/www/html"
echo " 🚀 占用极低，完美适配1G硬盘LXC容器"
echo "====================================="
