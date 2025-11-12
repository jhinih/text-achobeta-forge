# 🚀 Forge项目快速开始指南

## 一分钟快速部署

### 方法一：使用自动化脚本（推荐）
```bash
# 运行自动部署脚本
./scripts/setup.sh

# 生产环境部署
./scripts/setup.sh prod

# 清理环境
./scripts/setup.sh clean
```

### 方法二：手动部署
```bash
# 1. 启动基础服务
docker-compose up -d mysql redis

# 2. 等待服务启动（约30秒）
docker-compose logs -f mysql redis

# 3. 构建并启动应用
docker-compose up -d --build app

# 4. 检查服务状态
docker-compose ps

# 5. 测试应用
curl http://localhost:8080/health
```

## 🔧 常用命令

```bash
# 查看所有服务状态
docker-compose ps

# 查看应用日志
docker-compose logs -f app

# 重启应用
docker-compose restart app

# 停止所有服务
docker-compose down

# 完全清理（包括数据）
docker-compose down -v
```

## 📊 服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| 应用 | 8080 | Web应用主端口 |
| MySQL | 3306 | 数据库端口 |
| Redis | 6379 | 缓存端口 |
| Nginx | 80/443 | 反向代理（生产环境）|

## 🐛 故障排除

### 应用无法启动
```bash
# 查看详细错误
docker-compose logs app

# 检查端口占用
sudo lsof -i :8080
```

### 数据库连接失败
```bash
# 检查MySQL状态
docker-compose ps mysql

# 测试数据库连接
docker-compose exec mysql mysql -u fortest -p
```

## 🐳 Docker Hub 镜像

我们的CI/CD会自动将镜像推送到Docker Hub：

```bash
# 拉取最新镜像
docker pull jhinih/text-achobeta-forge:latest
```

## 🔧 GitHub Secrets 配置

要让CI/CD正常工作，请在GitHub仓库中配置以下Secrets：

```
DOCKER_HUB_PASSWORD=你的Docker Hub密码或Token
```

## 📚 工作流配置

项目包含简化的GitHub Actions工作流：

| 文件 | 用途 | 触发条件 |
|------|------|----------|
| `docker.yml` | 简化Docker构建并推送 | 推送到master分支 |

## 📚 详细文档

完整的部署和配置指南请参考：[DOCKER_CICD_GUIDE.md](./DOCKER_CICD_GUIDE.md)

## ✅ 验证部署

成功部署后，访问以下地址验证：

- **健康检查**: http://localhost:8080/health
- **API文档**: http://localhost:8080/api/docs （如果已配置）

祝您使用愉快！🎉