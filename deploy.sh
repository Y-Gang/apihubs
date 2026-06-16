#!/bin/bash
# ============================================
#  APIHubs 一键部署脚本
#  适用于 Ubuntu 22.04 LTS / Amazon Linux 2023
# ============================================

set -e

echo "========================================="
echo "  APIHubs 一键部署"
echo "========================================="

# ---------- 1. 系统更新 ----------
echo "[1/5] 更新系统..."
sudo apt-get update -y && sudo apt-get upgrade -y

# ---------- 2. 安装 Docker ----------
echo "[2/5] 安装 Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "Docker 安装完成，可能需要重新登录以生效用户组"
else
    echo "Docker 已安装，跳过"
fi

# ---------- 3. 安装 Docker Compose ----------
if ! command -v docker compose &> /dev/null; then
    sudo apt-get install -y docker-compose-plugin 2>/dev/null || {
        sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    }
fi
echo "Docker Compose 就绪 ✓"

# ---------- 4. 拉取项目 ----------
echo "[3/5] 拉取部署配置..."
DEPLOY_DIR="/opt/apihubs"
sudo mkdir -p $DEPLOY_DIR

# 如果已有 .env 则保留
if [ -f "$DEPLOY_DIR/.env" ]; then
    echo "检测到已有 .env，保留不动"
    ENV_EXISTS=true
else
    ENV_EXISTS=false
fi

# 复制配置文件
sudo cp docker-compose.yml $DEPLOY_DIR/
sudo cp .env.example $DEPLOY_DIR/.env.example
sudo cp -r nginx $DEPLOY_DIR/

if [ "$ENV_EXISTS" = false ]; then
    sudo cp .env.example $DEPLOY_DIR/.env
    echo "⚠️  请编辑 $DEPLOY_DIR/.env 修改密码！"
fi

cd $DEPLOY_DIR

# ---------- 5. 启动服务 ----------
echo "[4/5] 启动 New API + PostgreSQL + Redis..."
sudo docker compose up -d

echo "[5/5] 安装 Nginx & Certbot..."
sudo apt-get install -y nginx certbot python3-certbot-nginx

# 配置 Nginx
sudo cp nginx/new-api.conf /etc/nginx/conf.d/new-api.conf
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
sudo nginx -t && sudo systemctl restart nginx && sudo systemctl enable nginx

# 等待服务就绪
echo "等待 New API 启动..."
for i in $(seq 1 30); do
    if curl -s http://localhost:3000/api/status | grep -q "success"; then
        echo ""
        echo "========================================="
        echo "  🎉 部署完成！"
        echo "========================================="
        echo "  HTTP: http://$(curl -s ifconfig.me)"
        echo "  域名: http://apihubs.eu.cc (DNS解析后)"
        echo "  默认账号: root / 123456"
        echo ""
        echo "  ⚠️  立即修改默认密码！"
        echo "  ⚠️  DNS生效后执行 SSL 签发："
        echo "  sudo certbot --nginx -d apihubs.eu.cc"
        echo "========================================="
        exit 0
    fi
    echo "  等待中... ($i/30)"
    sleep 2
done

echo "⚠️  New API 启动超时，请检查日志："
echo "  sudo docker compose logs new-api"
