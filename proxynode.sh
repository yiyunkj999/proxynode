#!/bin/bash

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
PLAIN="\033[0m"

menu() {
    clear
    echo -e "${GREEN}============================================${PLAIN}"
    echo -e "${GREEN}              proxynode 管理菜单${PLAIN}"
    echo -e "${GREEN}============================================${PLAIN}"
    echo ""
    echo -e "${YELLOW} 1.${PLAIN} 更换软件源"
    echo -e "${YELLOW} 2.${PLAIN} 安装Docker"
    echo -e "${YELLOW} 3.${PLAIN} 开启Docker的IPv6"
    echo -e "${YELLOW} 4.${PLAIN} 安装Proxynode节点"
    echo -e "${YELLOW} 5.${PLAIN} 查看Proxynode日志"
    echo -e "${YELLOW} 6.${PLAIN} 自定义SSH端口"
    echo -e "${YELLOW} 7.${PLAIN} 开启BBR加速"
    echo -e "${YELLOW} 0.${PLAIN} 退出菜单"
    echo ""
    echo -n -e "请选择操作 [0-7]："  # 修改范围为0-7
    read -r num

    case "$num" in
        1)
            echo -e "\n${YELLOW}正在更换系统源...${PLAIN}"
            bash <(wget --no-check-certificate -qO- https://download.bt.cn/tools/fix_source.sh)
            echo -e "${GREEN}完成！${PLAIN}"
            sleep 2
            menu
            ;;
        2)
            echo -e "\n${YELLOW}正在安装 Docker...${PLAIN}"
            curl -fsSL https://get.docker.com | sh
            systemctl start docker
            systemctl enable docker
            echo -e "${GREEN}Docker 安装并启动完成！${PLAIN}"
            sleep 2
            menu
            ;;
        3)
            echo -e "\n${YELLOW}正在配置 Docker IPv6...${PLAIN}"
            cat > /etc/docker/daemon.json << EOF
{
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:1::/64"
}
EOF
            systemctl restart docker
            echo -e "${GREEN}IPv6 配置完成！${PLAIN}"
            sleep 2
            menu
            ;;
        4)
            clear
            echo -e "${YELLOW}========== Docker 账号登录 ==========${PLAIN}"
            # 输入Docker用户名
            read -p "请输入 Docker 用户名：" DOCKER_USER
            if [[ -z "$DOCKER_USER" ]]; then
                echo -e "${RED}用户名不能为空！${PLAIN}"
                sleep 2
                menu
            fi
            
            # 输入Docker密码（不显示明文）
            echo -n "请输入 Docker 密码："
            read -s DOCKER_PWD
            echo ""
            
            # 执行登录
            echo -e "\n${YELLOW}正在登录 Docker...${PLAIN}"
            echo "$DOCKER_PWD" | docker login -u "$DOCKER_USER" --password-stdin
            if [ $? -ne 0 ]; then
                echo -e "${RED}Docker 登录失败！请检查账号密码${PLAIN}"
                sleep 3
                menu
            fi
            echo -e "${GREEN}Docker 登录成功！${PLAIN}"
            
            # 端口配置
            echo -e "\n${YELLOW}========== Proxynode 端口配置 ==========${PLAIN}"
            echo -n -e "请输入需要映射的本地端口(默认 80)："
            read -r PORT
            [[ -z "$PORT" ]] && PORT="80"
            if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}错误：端口必须是纯数字！${PLAIN}"
                sleep 2
                menu
            fi
            
            # 删除旧容器
            docker rm -f proxynode >/dev/null 2>&1
            
            # 启动容器
            echo -e "\n${YELLOW}正在启动 proxynode，映射端口：${PORT}${PLAIN}"
            docker run -d \
              --name proxynode \
              --restart always \
              --log-opt max-size=2m \
              --log-opt max-file=1 \
              -p "${PORT}:8080/tcp" \
              yiyunkj888/proxynode:v1.0
              
            echo -e "${GREEN}proxynode 启动成功！映射端口：${PORT}${PLAIN}"
            sleep 3
            menu
            ;;
        5)
            echo -e "\n${YELLOW}实时日志（按 Ctrl+C 退出）${PLAIN}"
            docker logs -f proxynode
            menu
            ;;
        6)
            clear
            echo -e "${YELLOW}========== 修改SSH端口 ==========${PLAIN}"
            # 输入新端口
            read -p "请输入新的SSH端口(1-65535)：" SSH_PORT
            # 端口校验
            if [[ -z "$SSH_PORT" || ! "$SSH_PORT" =~ ^[0-9]+$ || "$SSH_PORT" -lt 1 || "$SSH_PORT" -gt 65535 ]]; then
                echo -e "${RED}错误：端口必须是1-65535之间的数字！${PLAIN}"
                sleep 2
                menu
            fi

            # 修改SSH配置文件
            sed -i.bak -E "s/^#?Port [0-9]+/Port $SSH_PORT/" /etc/ssh/sshd_config
            # 确保没有重复Port配置
            sed -i '/^Port/!b;:a;N;/.*/ba' /etc/ssh/sshd_config

            # 防火墙放行端口（适配firewalld/ufw）
            if command -v firewall-cmd >/dev/null 2>&1; then
                firewall-cmd --permanent --add-port="$SSH_PORT"/tcp
                firewall-cmd --reload
            elif command -v ufw >/dev/null 2>&1; then
                ufw allow "$SSH_PORT"/tcp
                ufw reload
            fi

            # 重启SSH服务
            systemctl restart sshd || systemctl restart ssh

            echo -e "${GREEN}SSH端口修改成功！新端口：$SSH_PORT${PLAIN}"
            echo -e "${YELLOW}请使用新端口连接SSH！${PLAIN}"
            sleep 3
            menu
            ;;
        7)  # 新增：一键开启BBR
            clear
            echo -e "${YELLOW}========== 开启BBR加速 ==========${PLAIN}"
            echo -e "\n正在配置BBR参数..."
            
            # 写入配置（去重避免重复添加）
            sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
            sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
            
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            
            # 加载配置
            sysctl -p
            
            echo -e "\n${GREEN}BBR 配置已生效！${PLAIN}"
            echo -e "\n${YELLOW}========== 查看BBR状态 ==========${PLAIN}"
            # 查看可用拥塞控制算法
            sysctl net.ipv4.tcp_available_congestion_control
            # 查看BBR模块
            lsmod | grep bbr
            
            echo -e "\n${GREEN}BBR 开启完成！${PLAIN}"
            echo -e "${YELLOW}服务器网络加速已生效！${PLAIN}"
            sleep 5
            menu
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}输入错误，请重新选择${PLAIN}"
            sleep 1
            menu
            ;;
    esac
}

menu
