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
command -v git >/dev/null 2>&1 || { echo >&2 "需要 git 但未安装。正在尝试安装..."; apt-get update && apt-get install -y git || yum install -y git; }
command -v docker >/dev/null 2>&1 || { echo >&2 "需要 docker 但未安装。正在尝试安装..."; curl -fsSL https://get.docker.com | bash; systemctl enable docker && systemctl start docker; }
if ! command -v docker-compose >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        echo >&2 "需要 docker-compose 但未安装。正在尝试安装..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        DOCKER_COMPOSE_CMD="docker-compose"
    fi
else
    DOCKER_COMPOSE_CMD="docker-compose"
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
echo "正在从 GitHub 拉取代码到 $INSTALL_DIR..."
if [ -d "$INSTALL_DIR" ]; then
    echo "目录 $INSTALL_DIR 已存在，尝试更新..."
    cd $INSTALL_DIR && git pull
else
    git clone https://github.com/SIJULY/2FA-TOTP.git $INSTALL_DIR
fi

cd $INSTALL_DIR || exit 1

# 生成 Caddyfile
echo "正在生成 Caddyfile..."
cat > Caddyfile <<EOF
$DOMAIN_NAME {
    reverse_proxy web:80
}
EOF

# 启动服务
echo "正在启动 Docker 容器..."
$DOCKER_COMPOSE_CMD up -d --build

echo ""
echo "=========================================="
echo "安装完成！"
echo "请访问: https://$DOMAIN_NAME"
echo "注意: Caddy 会自动为您配置 HTTPS 证书。如果刚解析完域名，可能需要等待一小段时间生效。"
echo "=========================================="