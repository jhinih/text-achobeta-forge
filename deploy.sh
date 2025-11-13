#!/bin/bash

echo "🚀 开始部署 text-achobeta-forge..."

# 拉取最新镜像
echo "📥 拉取最新镜像..."
docker pull jhinih/text-achobeta-forge:latest

# 停止并删除旧容器
echo "🛑 停止旧容器..."
docker stop text-achobeta-forge-app 2>/dev/null || true
docker rm text-achobeta-forge-app 2>/dev/null || true

# 运行新容器
echo "▶️ 启动新容器..."
docker run -d \
  --name text-achobeta-forge-app \
  --restart unless-stopped \
  -p 8080:8080 \
  jhinih/text-achobeta-forge:latest

# 检查容器状态
echo "🔍 检查容器状态..."
sleep 3
if docker ps | grep -q text-achobeta-forge-app; then
    echo "✅ 部署成功！"
    echo "🌐 应用访问地址: http://localhost:8080"
else
    echo "❌ 部署失败，查看日志:"
    docker logs text-achobeta-forge-app
fi

# 清理无用镜像
echo "🧹 清理无用镜像..."
docker image prune -f

echo "🎉 部署完成！"