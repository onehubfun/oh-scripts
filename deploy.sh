#!/bin/bash

# 检查是否以root用户运行
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "请以root用户运行此脚本"
    exit 1
  fi
}

# 定义颜色
define_colors() {
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m' # No Color
}

# GitHub API URL
define_urls() {
  GITHUB_API_URL="https://api.github.com/repos/onehubfun/one-shell/contents/compose"
  GITHUB_RAW_URL="https://raw.githubusercontent.com/onehubfun/one-shell/main/compose"
}

# 检查并安装依赖项
install_dependencies() {
  echo "检查并安装依赖项..."

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
  else
    echo "无法检测到操作系统版本"
    exit 1
  fi

  case "$OS" in
    ubuntu|debian)
      if ! command -v curl &> /dev/null; then
        apt-get update
        apt-get install -y curl
      fi
      if ! command -v jq &> /dev/null; then
        apt-get update
        apt-get install -y jq
      fi
      ;;
    centos|fedora)
      if ! command -v curl &> /dev/null; then
        yum install -y curl
      fi
      if ! command -v jq &> /dev/null; then
        yum install -y jq
      fi
      ;;
    *)
      echo "不支持的操作系统: $OS"
      exit 1
      ;;
  esac

  echo -e "${GREEN}依赖项检查和安装完成${NC}"
}

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

# 获取compose文件夹下的内容
get_compose_contents() {
  curl -s $GITHUB_API_URL | jq -r '.[] | select(.type == "dir") | .name'
}

# 解析文件夹名称为编号和应用名称
parse_folder_names() {
  local folders=("$@")
  for folder in "${folders[@]}"; do
    local number=$(echo $folder | cut -d'-' -f1)
    local app_name=$(echo $folder | cut -d'-' -f2-)
    echo "$number) $app_name"
  done
}

# 下载文件夹内容
download_folder() {
  local folder_path=$1
  local dest_dir=$2

  mkdir -p "$dest_dir"
  cd "$dest_dir"

  local contents=$(curl -s "$GITHUB_API_URL/$folder_path" | jq -c '.[]')
  for item in $contents; do
    local name=$(echo $item | jq -r '.name')
    local type=$(echo $item | jq -r '.type')

    if [ "$type" == "file" ]; then
      download_url="$GITHUB_RAW_URL/$folder_path/$name"
      echo "下载文件: $download_url"
      curl -s -O "$download_url"
    elif [ "$type" == "dir" ]; then
      download_folder "$folder_path/$name" "$dest_dir/$name"
    fi
  done
}

# 选择并下载应用
select_and_download_app() {
  folders=($(get_compose_contents))

  echo "应用列表："
  parse_folder_names "${folders[@]}"

  read -rp "请选择要安装的应用编号: " app_number

  selected_folder=""
  for folder in "${folders[@]}"; do
    if [[ $folder == $app_number-* ]]; then
      selected_folder=$folder
      break
    fi
  done

  if [ -z "$selected_folder" ]; then
    echo -e "${RED}无效的编号${NC}"
    exit 1
  fi

  app_name=$(echo $selected_folder | cut -d'-' -f2-)
  read -rp "请输入安装路径 (默认: /opt/stacks): " install_path
  install_path=${install_path:-/opt/stacks}

  if [ -d "$install_path/$app_name" ]; then
    read -rp "安装路径已存在，是否继续安装并删除原有文件夹？(默认: y): " continue_install
    continue_install=${continue_install:-y}

    if [[ $continue_install =~ ^(y|yes|Y)$ ]]; then
      rm -rf "$install_path/$app_name"
    else
      echo -e "${RED}安装已取消${NC}"
      exit 1
    fi
  fi

  mkdir -p "$install_path/$app_name"
  cd "$install_path/$app_name"

  echo "下载应用文件..."
  download_folder "$selected_folder" "$install_path/$app_name"

  if [ -f "deploy.sh" ]; then
    echo "运行 deploy.sh 脚本..."
    bash deploy.sh "$install_path/$app_name"
  fi

  read -rp "是否启动应用? (默认: y): " start_app
  start_app=${start_app:-y}

  if [[ $start_app =~ ^(yes|y|Y)$ ]]; then
    docker compose up -d
  fi

  echo -e "${GREEN}应用安装完成${NC}"
}

# 主函数
main() {
  check_root
  define_colors
  define_urls
  install_dependencies
  clear
  show_banner
  select_and_download_app
}

# 执行主函数
main