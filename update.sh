#!/bin/bash
# ============================================
#  APIHubs 更新脚本
#  在服务器上运行：拉取最新配置 + 重启服务
# ============================================

set -e

DEPLOY_DIR="/opt/apihubs"
cd $DEPLOY_DIR

echo "=== 拉取最新配置 ==="
git pull origin main

echo "=== 拉取最新 Docker 镜像 ==="
sudo docker compose pull

echo "=== 重启服务 ==="
sudo docker compose up -d

echo "=== 清理旧镜像 ==="
sudo docker image prune -f

echo "=== 服务状态 ==="
sudo docker compose ps

echo "✅ 更新完成！"
