#!/bin/bash

# 生成随机端口号函数
generate_random_port() {
    echo $((RANDOM % 1000 + 30000))
}

# 生成随机UUID函数
generate_random_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# 提示用户输入监听端口号
read -p "请输入监听端口号（默认随机生成30000-31000之间的端口号）: " listen_port
listen_port=${listen_port:-$(generate_random_port)}

# 提示用户输入验证密码
read -p "请输入验证密码（默认随机生成32位UUID）: " password
password=${password:-$(generate_random_uuid)}

# 提示用户是否开启端口跳跃
read -p "是否开启端口跳跃？(Y/n): " enable_port_hop
enable_port_hop=${enable_port_hop:-y}

if [[ $enable_port_hop =~ ^(是|yes|y|Y)$ ]]; then
    read -p "请输入端口跳跃起始范围（默认31000）: " port_hop_start
    read -p "请输入端口跳跃结束范围（默认32000）: " port_hop_end
    port_hop_start=${port_hop_start:-31000}
    port_hop_end=${port_hop_end:-32000}
    
    # 检查范围合法性
    if [[ "$port_hop_start" -ge "$port_hop_end" ]]; then
        echo "端口跳跃起始范围必须小于结束范围。"
        exit 1
    fi

    # 配置iptables规则
    iptables -t nat -A PREROUTING -i eth0 -p udp --dport "$port_hop_start:$port_hop_end" -j DNAT --to-destination :"$listen_port"
    ip6tables -t nat -A PREROUTING -i eth0 -p udp --dport "$port_hop_start:$port_hop_end" -j DNAT --to-destination :"$listen_port"

    ports_line="  ports: $port_hop_start-$port_hop_end"
else
    ports_line=""
fi

# 提示用户输入服务器域名
read -p "请输入服务器域名（example.com）: " server_domain

# 生成配置文件config.yaml
cat << EOF > "$1/config.yaml"
listen: :$listen_port
transport:
  udp:
    hopInterval: 30s
auth:
  type: password
  password: $password
tls:
  cert: /ssl/fullchain.cer
  key: /ssl/private.key
ignoreClientBandwidth: true
bandwidth:
  up: 1 gbps
  down: 1 gbps
quic:
  initStreamReceiveWindow: 26843545
  maxStreamReceiveWindow: 26843545
  initConnReceiveWindow: 67108864
  maxConnReceiveWindow: 67108864
masquerade:
  type: proxy
  proxy:
    url: https://news.ycombinator.com/
    rewriteHost: true
EOF

# 生成proxies.yaml文件
cat << EOF > "$1/proxies.yaml"
proxies:
- name: "hysteria2"
  type: hysteria2
  server: $server_domain
  port: $listen_port
  password: $password
$ports_line
EOF

echo "配置已完成，配置文件保存至 $1/config.yaml 和 $1/proxies.yaml"