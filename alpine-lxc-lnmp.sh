#!/bin/sh
clear
echo "============================================="
echo "  LXC Alpine 一键部署 Nginx+PHP7.2+vsftpd"
echo "  FTP用户：proxynode | 自动适配所有Alpine版本"
echo "============================================="
sleep 2

# 1. 强制切换为 Alpine 3.12 源（原生支持PHP7.2，兼容所有版本）
echo -e "\n[1/8] 切换软件源..."
cp /etc/apk/repositories /etc/apk/repositories.bak
cat > /etc/apk/repositories << EOF
http://mirrors.aliyun.com/alpine/v3.12/main
http://mirrors.aliyun.com/alpine/v3.12/community
EOF
apk update && apk upgrade -y

# 2. 安装所有服务
echo -e "\n[2/8] 安装 Nginx+PHP7.2+FTP+依赖..."
apk add nginx php7.2 php7.2-fpm php7.2-curl php7.2-mbstring php7.2-gd php7.2-xml php7.2-json vsftpd iptables-persistent -y

# 3. 配置PHP-FPM权限（解决403）
echo -e "\n[3/8] 配置PHP7.2-FPM..."
sed -i 's/user = nobody/user = nginx/g' /etc/php7.2/php-fpm.d/www.conf
sed -i 's/group = nobody/group = nginx/g' /etc/php7.2/php-fpm.d/www.conf

# 4. 创建网站目录+权限
echo -e "\n[4/8] 创建网站目录..."
mkdir -p /var/www/site
chown -R proxynode:nginx /var/www/site 2>/dev/null
chmod -R 755 /var/www/site

# 5. 创建FTP用户 proxynode
echo -e "\n[5/8] 创建FTP用户 proxynode，请输入密码（输入不显示）..."
adduser -D -s /sbin/nologin proxynode 2>/dev/null
passwd proxynode

# 6. 配置FTP服务（安全加固）
echo -e "\n[6/8] 配置vsftpd..."
cat > /etc/vsftpd.conf << EOF
local_enable=YES
write_enable=YES
local_umask=022
anonymous_enable=NO
chroot_local_user=YES
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
xferlog_enable=NO
port_enable=NO
cmds_allowed=USER,PASS,CWD,LIST,NLST,RETR,STOR,APPE,DELE,RMD,MKD,RNFR,RNTO,SIZE,MDTM
EOF

# 7. 配置Nginx站点（自动获取容器IP）
echo -e "\n[7/8] 配置Nginx虚拟主机..."
LOCAL_IP=$(hostname -i | awk '{print $1}')
cat > /etc/nginx/conf.d/site.conf << EOF
server {
    listen 80;
    server_name $LOCAL_IP;
    root /var/www/site;
    index index.html index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\. {
        deny all;
    }
}
EOF

# 8. 防火墙放行+服务自启
echo -e "\n[8/8] 配置防火墙+启动服务..."
# 放行端口
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 21 -j ACCEPT
iptables -A INPUT -p tcp --dport 40000:50000 -j ACCEPT
# 保存规则
/etc/init.d/iptables-persistent save
rc-update add iptables-persistent default

# 启动所有服务
rc-update add nginx default
rc-update add php-fpm7.2 default
rc-update add vsftpd default
rc-service nginx restart
rc-service php-fpm7.2 restart
rc-service vsftpd restart

# 创建PHP探针
echo "<?php phpinfo(); ?>" > /var/www/site/index.php
chown proxynode:nginx /var/www/site/index.php

# 完成提示
clear
echo "============================================="
echo "              部署完成！"
echo "============================================="
echo "网站访问地址：http://$LOCAL_IP"
echo "FTP信息："
echo "  主机：$LOCAL_IP"
echo "  端口：21"
echo "  用户：proxynode"
echo "  密码：你刚才设置的密码"
echo "网站目录：/var/www/site"
echo "============================================="
