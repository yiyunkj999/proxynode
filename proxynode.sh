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
    echo -e "${YELLOW} 5.${PLAIN} 查看容器日志"
    echo -e "${YELLOW} 0.${PLAIN} 退出"
    echo ""
    echo -n -e "请选择操作 [0-5]："
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
            docker rm -f proxynode >/dev/null 2>&1
            echo -e "\n${YELLOW}正在启动 proxynode...${PLAIN}"
            docker run -d \
              --name proxynode \
              --net host \
              --restart always \
              --log-opt max-size=2m \
              --log-opt max-file=1 \
              yiyunkj888/proxynode:v1.0
            echo -e "${GREEN}启动成功！${PLAIN}"
            sleep 2
            menu
            ;;
        5)
            echo -e "\n${YELLOW}实时日志（按 Ctrl+C 退出）${PLAIN}"
            docker logs -f proxynode
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
