#!/usr/bin/env python3
"""
简单的webhook部署服务器
运行在服务器上，接收GitHub Actions的部署请求
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import subprocess
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DeployHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            # 读取请求数据
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))

            logger.info(f"收到部署请求: {data}")

            if data.get('event') == 'deploy':
                # 执行部署脚本
                self.deploy_container()

                # 返回成功响应
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"status": "success", "message": "部署成功"}).encode())
            else:
                self.send_response(400)
                self.end_headers()

        except Exception as e:
            logger.error(f"部署失败: {e}")
            self.send_response(500)
            self.end_headers()

    def deploy_container(self):
        """部署容器"""
        commands = [
            "docker pull jhinih/text-achobeta-forge:latest",
            "docker stop text-achobeta-forge-app || true",
            "docker rm text-achobeta-forge-app || true",
            "docker run -d --name text-achobeta-forge-app --restart unless-stopped -p 8080:8080 jhinih/text-achobeta-forge:latest",
            "docker image prune -f"
        ]

        for cmd in commands:
            logger.info(f"执行命令: {cmd}")
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            if result.returncode != 0 and "|| true" not in cmd:
                raise Exception(f"命令执行失败: {cmd}, 错误: {result.stderr}")
            logger.info(f"命令输出: {result.stdout}")

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 9000), DeployHandler)
    logger.info("Webhook服务器启动在端口 9000")
    logger.info("等待部署请求...")
    server.serve_forever()