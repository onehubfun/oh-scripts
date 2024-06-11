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
      if ! command -v vim &> /dev/null; then
        apt-get update
        apt-get install -y vim
      fi
      ;;
    centos|fedora)
      if ! command -v curl &> /dev/null; then
        yum install -y curl
      fi
      if ! command -v jq &> /dev/null; then
        yum install -y jq
      fi
      if ! command -v vim &> /dev/null; then
        yum install -y vim
      fi
      ;;
    *)
      echo "不支持的操作系统: $OS"
      exit 1
      ;;
  esac

  echo -e "${GREEN}依赖项检查和安装完成${NC}"
  clear  # 添加清屏操作
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

# 选择应用
select_app() {
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

  echo $selected_folder
}

# 设置安装路径
set_install_path() {
  local app_name=$1
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
  echo $install_path
}

# 检查并编辑环境变量文件
check_and_edit_env_files() {
  local install_path=$1
  local app_name=$2

  cd "$install_path/$app_name"

  env_files=$(find . -type f -name ".env" -o -name "*.env")
  if [ -n "$env_files" ]; then
    echo "检测到以下环境变量文件，请根据需要修改："
    for file in $env_files; do
      echo "$file"
      read -rp "是否编辑此文件? (默认: y): " edit_file
      edit_file=${edit_file:-y}
      if [[ $edit_file =~ ^(yes|y|Y)$ ]]; then
        vim "$file"
      fi
    done
  fi
}

# 运行部署脚本
run_deploy_script() {
  local install_path=$1
  local app_name=$2

  if [ -f "$install_path/$app_name/deploy.sh" ]; then
    echo "运行 deploy.sh 脚本..."
    bash "$install_path/$app_name/deploy.sh" "$install_path/$app_name"
  fi
}

# 检查或创建 Docker 网络
ensure_docker_network() {
    if ! docker network ls | grep -q "onenet"; then
        echo "创建 Docker 网络 onenet..."
        docker network create --driver bridge onenet
        if [[ $? -ne 0 ]]; then
            echo "Docker 网络创建失败。"
            exit 1
        fi
    else
        echo "Docker 网络 onenet 已存在。"
    fi
}

# 启动应用
start_application() {
  read -rp "是否启动应用? (默认: y): " start_app
  start_app=${start_app:-y}

  if [[ $start_app =~ ^(yes|y|Y)$ ]]; then
    docker compose up -d
    if [[ $? -ne 0 ]]; then
      echo "容器启动失败，请检查配置。"
      exit 1
    fi
  fi

  echo -e "${GREEN}应用安装完成${NC}"
}

# 主函数
main() {
  check_root
  define_colors
  define_urls
  install_dependencies
  show_banner

  # 展示可安装应用列表
  folders=($(get_compose_contents))
  parse_folder_names "${folders[@]}"
  selected_folder=$(select_app)

  app_name=$(echo $selected_folder | cut -d'-' -f2-)
  install_path=$(set_install_path "$app_name")

  echo "下载应用文件..."
  download_folder "$selected_folder" "$install_path/$app_name"

  check_and_edit_env_files "$install_path" "$app_name"
  run_deploy_script "$install_path" "$app_name"
  ensure_docker_network
  start_application
}

# 执行主函数
main