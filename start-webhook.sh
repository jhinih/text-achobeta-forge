#!/bin/bash

echo "🚀 启动 Webhook 部署服务..."

# 检查Python是否安装
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 未安装，请先安装Python3"
    exit 1
fi

# 检查Docker是否运行
if ! docker ps &> /dev/null; then
    echo "❌ Docker 未运行，请启动Docker服务"
    exit 1
fi

# 杀死之前的进程
pkill -f webhook-deploy.py 2>/dev/null || true

# 启动webhook服务器
echo "📡 启动Webhook服务器在端口 9000..."
python3 webhook-deploy.py &

# 保存进程ID
echo $! > webhook.pid
echo "✅ Webhook服务器已启动，PID: $(cat webhook.pid)"
echo "📝 要停止服务器，运行: kill $(cat webhook.pid)"
echo "🌐 Webhook URL: http://你的服务器IP:9000"

# 显示服务状态
sleep 2
if ps -p $(cat webhook.pid) > /dev/null; then
    echo "✅ Webhook服务器运行正常"
else
    echo "❌ Webhook服务器启动失败"
fi