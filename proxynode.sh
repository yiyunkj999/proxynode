#!/bin/bash

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
PLAIN="\033[0m"

DOCKER_IMG="yiyunkj888/proxynode:latest"
DOCKER_NAME="proxynode"

menu() {
    while true; do
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
        echo -e "${YELLOW} 7.${PLAIN} 开启BBR加速器"
        echo -e "${YELLOW} 8.${PLAIN} 开启WARP双栈网络"
        echo -e "${YELLOW} 9.${PLAIN} 卸载Proxynode节点/镜像"
        echo -e "${YELLOW} 0.${PLAIN} 退出菜单"
        echo ""
        echo -n -e "请选择操作 [0-9]："
        read -r num

        case "$num" in
            1)
                echo -e "\n${YELLOW}正在更换系统源...${PLAIN}"
                bash <(wget --no-check-certificate -qO- https://download.bt.cn/tools/fix_source.sh)
                echo -e "${GREEN}完成！${PLAIN}"
                pause
                ;;
            2)
                echo -e "\n${YELLOW}正在安装 Docker...${PLAIN}"
                curl -fsSL https://get.docker.com | sh
                systemctl start docker
                systemctl enable docker
                echo -e "${GREEN}Docker 安装并启动完成！${PLAIN}"
                pause
                ;;
            3)
                echo -e "\n${YELLOW}正在配置 Docker IPv6...${PLAIN}"

                # 读取已有配置，追加 IPv6 设置（不覆盖）
                local conf="/etc/docker/daemon.json"
                if [ -f "$conf" ]; then
                    # 已有配置，用 jq 追加；没有 jq 则提示
                    if command -v jq &>/dev/null; then
                        local tmp=$(mktemp)
                        jq '. + {"ipv6": true, "fixed-cidr-v6": "fd00:dead:beef::/48"}' "$conf" > "$tmp" \
                            && mv "$tmp" "$conf"
                    else
                        echo -e "${RED}请先安装 jq：apt install jq -y${PLAIN}"
                        pause
                        continue
                    fi
                else
                    cat > "$conf" << EOF
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:dead:beef::/48"
}
EOF
                fi

                systemctl restart docker
                echo -e "${GREEN}IPv6 配置完成！（子网 fd00:dead:beef::/48）${PLAIN}"
                pause
                ;;
            4)
                clear
                echo -e "${YELLOW}========== Docker 账号登录 ==========${PLAIN}"
                read -p "请输入 Docker 用户名：" DOCKER_USER
                if [[ -z "$DOCKER_USER" ]]; then
                    echo -e "${RED}用户名不能为空！${PLAIN}"
                    pause
                    continue
                fi

                echo -n "请输入 Docker 密码："
                read -s DOCKER_PWD
                echo ""

                echo -e "\n${YELLOW}正在登录 Docker...${PLAIN}"
                echo "$DOCKER_PWD" | docker login -u "$DOCKER_USER" --password-stdin
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Docker 登录失败！请检查账号密码${PLAIN}"
                    pause
                    continue
                fi
                echo -e "${GREEN}Docker 登录成功！${PLAIN}"

                echo -e "\n${YELLOW}========== Proxynode 端口配置 ==========${PLAIN}"
                echo -n -e "请输入需要映射的本地端口（默认 80）："
                read -r PORT
                [[ -z "$PORT" ]] && PORT="80"
                if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
                    echo -e "${RED}错误：端口必须是纯数字！${PLAIN}"
                    pause
                    continue
                fi

                docker rm -f "$DOCKER_NAME" >/dev/null 2>&1

                echo -e "\n${YELLOW}正在启动 proxynode，映射端口：${PORT}${PLAIN}"
                docker run -d \
                  --name "$DOCKER_NAME" \
                  --restart always \
                  --log-opt max-size=2m \
                  --log-opt max-file=1 \
                  -p "${PORT}:8080/tcp" \
                  "$DOCKER_IMG"

                echo -e "${GREEN}proxynode 启动成功！映射端口：${PORT}${PLAIN}"
                pause
                ;;
            5)
                echo -e "\n${YELLOW}实时日志（按 Ctrl+C 退出）${PLAIN}"
                docker logs -f "$DOCKER_NAME"
                echo -e "\n${YELLOW}日志查看已结束${PLAIN}"
                pause
                ;;
            6)
                clear
                echo -e "${YELLOW}========== 修改SSH端口 ==========${PLAIN}"
                read -p "请输入新的SSH端口（1-65535）：" SSH_PORT
                if [[ -z "$SSH_PORT" || ! "$SSH_PORT" =~ ^[0-9]+$ || "$SSH_PORT" -lt 1 || "$SSH_PORT" -gt 65535 ]]; then
                    echo -e "${RED}错误：端口必须是1-65535之间的数字！${PLAIN}"
                    pause
                    continue
                fi

                local conf="/etc/ssh/sshd_config"
                cp -f "$conf" "${conf}.bak"

                # 去掉已有的 Port 行，追加新端口
                sed -i "/^Port /d" "$conf"
                # 如果存在被注释的 Port 行也去掉
                sed -i "/^#Port /d" "$conf"
                echo "Port $SSH_PORT" >> "$conf"

                # 防火墙放行
                if command -v firewall-cmd >/dev/null 2>&1; then
                    firewall-cmd --permanent --add-port="$SSH_PORT"/tcp && firewall-cmd --reload
                elif command -v ufw >/dev/null 2>&1; then
                    ufw allow "$SSH_PORT"/tcp && ufw reload
                fi

                systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

                echo -e "${GREEN}SSH端口修改成功！新端口：$SSH_PORT${PLAIN}"
                echo -e "${YELLOW}请使用新端口连接SSH！原配置已备份至 ${conf}.bak${PLAIN}"
                pause
                ;;
            7)
                clear
                echo -e "${YELLOW}========== 开启BBR加速 ==========${PLAIN}"

                # 检查内核是否支持 BBR
                if ! modprobe tcp_bbr 2>/dev/null; then
                    echo -e "${RED}当前内核不支持 BBR，请先升级内核（5.x+）${PLAIN}"
                    pause
                    continue
                fi

                echo -e "\n正在配置BBR参数..."

                sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf

                echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
                echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

                sysctl -p

                echo -e "\n${GREEN}BBR 配置已生效！${PLAIN}"
                echo -e "\n${YELLOW}========== 查看BBR状态 ==========${PLAIN}"
                sysctl net.ipv4.tcp_available_congestion_control
                lsmod | grep bbr

                echo -e "\n${GREEN}BBR 开启完成！${PLAIN}"
                pause
                ;;
            8)
                clear
                echo -e "${YELLOW}========== 一键安装并开启 WARP ==========${PLAIN}"
                echo -e "\n正在下载 WARP 脚本..."
                wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh
                echo -e "\n${GREEN}WARP 脚本执行完成！${PLAIN}"
                pause
                ;;
            9)
                clear
                echo -e "${YELLOW}========== 卸载 Proxynode ==========${PLAIN}"
                echo ""
                echo -e "即将执行以下操作："
                echo -e "  ${YELLOW}•${PLAIN} 停止并删除容器 ${DOCKER_NAME}"
                echo -e "  ${YELLOW}•${PLAIN} 删除镜像 ${DOCKER_IMG}"
                echo ""

                # 停止容器
                if docker ps -a --format '{{.Names}}' | grep -q "^${DOCKER_NAME}$"; then
                    docker stop "$DOCKER_NAME" >/dev/null 2>&1
                    docker rm "$DOCKER_NAME" >/dev/null 2>&1
                    echo -e "${GREEN}✓ 容器 ${DOCKER_NAME} 已删除${PLAIN}"
                else
                    echo -e "${YELLOW}- 容器 ${DOCKER_NAME} 不存在，跳过${PLAIN}"
                fi

                # 删除镜像
                if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${DOCKER_IMG}$"; then
                    docker rmi "$DOCKER_IMG" >/dev/null 2>&1
                    echo -e "${GREEN}✓ 镜像 ${DOCKER_IMG} 已删除${PLAIN}"
                else
                    echo -e "${YELLOW}- 镜像 ${DOCKER_IMG} 不存在，跳过${PLAIN}"
                fi

                echo -e "\n${GREEN}卸载完成！${PLAIN}"
                pause
                ;;
            0)
                echo -e "\n${GREEN}再见！${PLAIN}"
                exit 0
                ;;
            *)
                echo -e "${RED}输入错误，请重新选择${PLAIN}"
                pause
                ;;
        esac
    done
}

pause() {
    echo -e "\n按任意键返回菜单..."
    read -n 1 -s
}

menu
