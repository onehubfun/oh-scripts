#!/bin/bash

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本"
  exit 1
fi

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 显示横幅和系统信息
show_banner() {
  echo -e "========================================"
  echo -e "=   ${RED}___${NC}             ${RED}_   _${NC}       _      ="
  echo -e "=  ${RED}/ _ \ ${NC}_ __   ___${RED}| | | |${NC}_   _| |__   ="
  echo -e "= ${RED}| | | |${NC} '_ \ / _ \\ ${RED}|_| |${NC} | | | '_ \  ="
  echo -e "= ${RED}| |_| |${NC} | | |  __/${RED}  _  |${NC} |_| | |_) | ="
  echo -e "=  ${RED}\___/${NC}|_| |_|\___${RED}|_| |_|${NC}\__._|_.__/  ="
  echo -e "========================================"
  echo -e "操作系统: ${GREEN}$(uname -o)${NC}"
  echo -e "内核版本: ${GREEN}$(uname -r)${NC}"
  echo -e "主机名: ${GREEN}$(hostname)${NC}"
  echo -e "CPU架构: ${GREEN}$(uname -m)${NC}"
  echo "========================================"
}

# 检测Linux发行版
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
  VERSION=$VERSION_ID
else
  echo "无法检测到操作系统版本"
  exit 1
fi

# 检查Docker和Docker Compose的安装情况
check_docker() {
  if command -v docker &> /dev/null; then
    echo -e "${GREEN}$(docker --version)${NC}"
  else
    echo -e "Docker ${RED}未安装${NC}"
  fi

  if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}$(docker-compose --version)${NC}"
  elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    echo -e "${GREEN}$(docker compose version)${NC}"
  else
    echo -e "Docker Compose ${RED}未安装${NC}"
  fi
  echo "========================================"
}

# 安装Docker的函数
install_docker() {
  echo "开始安装 Docker..."

  case "$OS" in
    ubuntu|debian)
      apt-get update
      apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
      curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io
      ;;
    centos)
      yum install -y yum-utils
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      yum install -y docker-ce docker-ce-cli containerd.io
      ;;
    fedora)
      dnf -y install dnf-plugins-core
      dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      dnf install -y docker-ce docker-ce-cli containerd.io
      ;;
    *)
      echo "不支持的操作系统: $OS"
      exit 1
      ;;
  esac

  # 启动并启用Docker服务
  systemctl start docker
  systemctl enable docker

  echo "Docker 安装完成并已启动"
}

# 卸载Docker的函数
uninstall_docker() {
  echo "开始卸载 Docker..."

  case "$OS" in
    ubuntu|debian)
      apt-get purge -y docker-ce docker-ce-cli containerd.io
      apt-get autoremove -y --purge
      rm -rf /usr/share/keyrings/docker-archive-keyring.gpg
      rm -rf /var/lib/docker
      rm -rf /var/lib/containerd
      ;;
    centos)
      yum remove -y docker-ce docker-ce-cli containerd.io
      rm -rf /var/lib/docker
      rm -rf /var/lib/containerd
      ;;
    fedora)
      dnf remove -y docker-ce docker-ce-cli containerd.io
      rm -rf /var/lib/docker
      rm -rf /var/lib/containerd
      ;;
    *)
      echo "不支持的操作系统: $OS"
      exit 1
      ;;
  esac

  echo "Docker 卸载完成"
}

# 主函数
main() {
  show_banner
  check_docker

  echo "请选择操作："
  echo "1) 安装 Docker"
  echo "2) 卸载 Docker"
  echo "3) 退出脚本"
  read -rp "输入选项: " choice

  case "$choice" in
    1)
      install_docker
      ;;
    2)
      uninstall_docker
      ;;
    3)
      exit 0
      ;;
    *)
      echo "无效的选项"
      exit 0
      ;;
  esac
}

# 执行主函数
main