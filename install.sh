#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以 root 权限运行。请使用 sudo 或切换到 root 用户再试。" 1>&2
   exit 1
fi

echo "=========================================="
echo "    2FA TOTP 动态验证码工具 一键安装脚本    "
echo "=========================================="
echo ""

# 检查环境依赖
command -v git >/dev/null 2>&1 || { echo >&2 "正在安装 git..."; apt-get update && apt-get install -y git || yum install -y git; }
command -v docker >/dev/null 2>&1 || { echo >&2 "正在安装 docker..."; curl -fsSL https://get.docker.com | bash; systemctl enable docker && systemctl start docker; }
if ! command -v docker-compose >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        echo >&2 "正在安装 docker-compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        DOCKER_COMPOSE_CMD="docker-compose"
    fi
else
    DOCKER_COMPOSE_CMD="docker-compose"
fi

# 自动检测并安装 Caddy
if ! command -v caddy >/dev/null 2>&1; then
    echo "未检测到本机安装 Caddy，正在尝试自动安装 Caddy..."
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
        apt-get update
        apt-get install caddy -y
    elif [ -f /etc/redhat-release ]; then
        yum install yum-plugin-copr -y
        yum copr enable @caddy/caddy -y
        yum install caddy -y
    else
        echo -e "\033[31m警告: 无法确定系统类型，跳过 Caddy 自动安装。如果后续失败，请手动安装 Caddy。\033[0m"
    fi
    
    if command -v caddy >/dev/null 2>&1; then
        systemctl enable caddy
        systemctl start caddy
        echo "Caddy 安装并启动完成！"
    fi
fi

# 尝试放行防火墙端口 (80 和 443)
echo "正在检查并配置防火墙..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow 80/tcp >/dev/null 2>&1
    ufw allow 443/tcp >/dev/null 2>&1
    echo "已尝试通过 ufw 放行 80 和 443 端口。"
elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --zone=public --add-port=80/tcp --permanent >/dev/null 2>&1
    firewall-cmd --zone=public --add-port=443/tcp --permanent >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
    echo "已尝试通过 firewalld 放行 80 和 443 端口。"
elif command -v iptables >/dev/null 2>&1; then
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT >/dev/null 2>&1
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT >/dev/null 2>&1
    command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1
    command -v service >/dev/null 2>&1 && service iptables save >/dev/null 2>&1
    echo "已尝试通过 iptables 放行 80 和 443 端口。"
fi

# 提示用户输入域名
read -p "请输入您已解析到本服务器的域名 (例如: 2fa.yourdomain.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo "错误：域名不能为空！"
    exit 1
fi

echo "使用域名: $DOMAIN_NAME"

# 下载项目代码
INSTALL_DIR="/opt/2fa-totp"
echo "正在从 GitHub 拉取最新代码到 $INSTALL_DIR..."
if [ -d "$INSTALL_DIR" ]; then
    cd $INSTALL_DIR
    git reset --hard HEAD >/dev/null 2>&1
    git pull
else
    git clone https://github.com/SIJULY/2FA-TOTP.git $INSTALL_DIR
    cd $INSTALL_DIR || exit 1
fi

# 停止可能运行的旧容器
$DOCKER_COMPOSE_CMD down >/dev/null 2>&1

# 启动 Web 服务 (映射到本机的 8011 端口)
echo "正在启动 Web 服务容器 (运行在本地 8011 端口)..."
$DOCKER_COMPOSE_CMD up -d --build

# 配置宿主机的 Caddy
echo "正在配置宿主机的 Caddy..."
CADDYFILE_PATH="/etc/caddy/Caddyfile"

if [ ! -d "/etc/caddy" ]; then
    mkdir -p /etc/caddy
fi

if [ ! -f "$CADDYFILE_PATH" ]; then
    touch "$CADDYFILE_PATH"
fi

# 检查 Caddyfile 中是否已经包含了该域名，避免重复添加
if grep -q "$DOMAIN_NAME" "$CADDYFILE_PATH"; then
    echo "域名 $DOMAIN_NAME 已存在于 $CADDYFILE_PATH 中，跳过添加。"
else
    # 备份原有的 Caddyfile (如果存在且不为空)
    if [ -s "$CADDYFILE_PATH" ]; then
        cp "$CADDYFILE_PATH" "${CADDYFILE_PATH}.bak.$(date +%F_%T)"
    fi
    
    # 将新域名的配置追加到 Caddyfile 末尾
    cat >> "$CADDYFILE_PATH" <<EOF

$DOMAIN_NAME {
    reverse_proxy 127.0.0.1:8011
}
EOF
    echo "已将 $DOMAIN_NAME 代理配置添加到 $CADDYFILE_PATH。"
fi

# 重载 Caddy 配置
echo "正在重载/启动 Caddy 配置..."
if systemctl is-active --quiet caddy; then
    systemctl reload caddy
else
    systemctl start caddy
fi

echo ""
echo "=========================================="
echo "安装和配置完成！"
echo "请访问: https://$DOMAIN_NAME"
echo "注意: 您的请求现在通过本机的 Caddy 转发到 Docker 容器内的 8011 端口。"
echo "=========================================="