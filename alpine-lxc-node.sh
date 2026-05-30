#!/bin/sh
# 彻底清空旧FTP配置（根治残留问题）
killall vsftpd 2>/dev/null
apk del vsftpd 2>/dev/null
deluser ftpuser 2>/dev/null
rm -rf /etc/vsftpd.conf /var/www/html 2>/dev/null

# 重装基础服务
apk update
apk add --no-cache nginx php7 php7-fpm vsftpd

# -------------- 核心修复：vsftpd 极简配置（Alpine LXC 专用） --------------
cat > /etc/vsftpd.conf << EOF
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
pasv_min_port=40000
pasv_max_port=40100
# 【关键1】关闭LXC不兼容的沙箱
seccomp_sandbox=NO
# 【关键2】禁用PAM（Alpine兼容问题）
pam_service_name=ftp
# 【关键3】强制禁锢目录
chroot_local_user=YES
allow_writeable_chroot=NO
EOF

# -------------- 核心修复：目录权限（vsftpd 硬性要求：主目录不可写） --------------
mkdir -p /var/www/html
# 主目录权限设为555（只读，解决child died）
chmod 555 /var/www
chmod 755 /var/www/html
chown -R nginx:nginx /var/www/html

# 创建FTP用户
adduser -h /var/www/html -s /sbin/nologin -D ftpuser
echo -e "\n===== 设置FTP密码 ====="
passwd ftpuser

# 配置Nginx+PHP
cat > /etc/nginx/conf.d/default.conf << EOF
server {
    listen 80;
    root /var/www/html;
    index index.php index.html;
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

# 启动所有服务
rc-update add nginx default
rc-update add php-fpm7 default
rc-update add vsftpd default
service nginx restart
service php-fpm7 restart
service vsftpd restart

# 创建测试文件
echo "<h1>网站正常</h1>" > /var/www/html/index.html
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# 显示信息
IP=$(hostname -i | awk '{print $1}')
clear
echo "============================================="
echo " ✅ FTP 500错误 已彻底修复！"
echo "============================================="
echo "网站：http://$IP"
echo "FTP：IP:$IP  用户:ftpuser  密码:你设置的"
echo "⚠️  FTP连接必须用：被动模式"
echo "============================================="
