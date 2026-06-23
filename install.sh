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

# 检查端口占用
if ss -tuln | grep -q ":80 " || netstat -tuln | grep -q ":80 "; then
    echo -e "\033[31m警告: 端口 80 已被占用！Caddy 可能无法启动并申请证书。请确保没有其他服务(如 Nginx, Apache)占用 80 端口。\033[0m"
fi
if ss -tuln | grep -q ":443 " || netstat -tuln | grep -q ":443 "; then
    echo -e "\033[31m警告: 端口 443 已被占用！Caddy 可能无法正常工作。\033[0m"
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

# 生成 Caddyfile
echo "正在生成 Caddyfile..."
cat > Caddyfile <<EOF
$DOMAIN_NAME {
    reverse_proxy web:80
}
EOF

# 启动服务
echo "正在启动服务 (Docker 容器)..."
$DOCKER_COMPOSE_CMD up -d --build

echo ""
echo "=========================================="
echo "部署完成！正在等待 Caddy 自动申请 SSL 证书..."
echo "请注意："
echo "1. 请确保您的域名 [$DOMAIN_NAME] 已经正确解析到本服务器的 IP。"
echo "2. 如果您使用了 Cloudflare，请将小黄云(代理状态)设置为【仅 DNS】，或者将 SSL/TLS 加密模式设置为【完全(Full)】。"
echo "3. SSL 证书申请通常需要 10~30 秒，如果访问报错 ERR_SSL_PROTOCOL_ERROR，请耐心等待并多刷新几次。"
echo "4. 某些云厂商（如阿里云、腾讯云、AWS）需要在网页控制台的安全组中手动放行 80 和 443 端口。"
echo "=========================================="
echo ""
echo "以下是 Caddy 近期的运行日志（如果您看到 'certificate obtained successfully' 表示证书申请成功）："
sleep 5
$DOCKER_COMPOSE_CMD logs --tail=15 caddy