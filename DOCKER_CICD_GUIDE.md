# Docker与CI/CD完整教学指南

## 📋 目录
- [项目概述](#项目概述)
- [Docker基础](#docker基础)
- [Dockerfile详解](#dockerfile详解)
- [Docker Compose详解](#docker-compose详解)
- [CI/CD流水线详解](#cicd流水线详解)
- [部署指南](#部署指南)
- [常见问题](#常见问题)
- [最佳实践](#最佳实践)

## 🎯 项目概述

这是一个基于Go语言和Gin框架的Web应用项目，使用MySQL作为数据库，Redis作为缓存。我们为该项目配置了完整的Docker容器化和CI/CD自动化部署流程。

### 技术栈
- **后端**: Go 1.23.4 + Gin框架
- **数据库**: MySQL 8.0
- **缓存**: Redis 7
- **容器化**: Docker + Docker Compose
- **CI/CD**: GitHub Actions
- **反向代理**: Nginx (生产环境)

## 🐳 Docker基础

### 什么是Docker？
Docker是一个容器化平台，可以将应用及其所有依赖打包成一个轻量级、可移植的容器。

### 核心概念
- **镜像(Image)**: 只读的容器模板
- **容器(Container)**: 镜像的运行实例
- **Dockerfile**: 构建镜像的脚本文件
- **Docker Compose**: 管理多容器应用的工具

### 安装Docker
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Windows
# 下载Docker Desktop for Windows

# macOS
# 下载Docker Desktop for Mac
```

### 基本命令
```bash
# 查看版本
docker --version
docker-compose --version

# 查看镜像
docker images

# 查看容器
docker ps -a

# 构建镜像
docker build -t 镜像名 .

# 运行容器
docker run -d --name 容器名 镜像名

# 查看日志
docker logs 容器名

# 进入容器
docker exec -it 容器名 /bin/sh
```

## 📄 Dockerfile详解

我们的Dockerfile使用多阶段构建来优化镜像大小：

```dockerfile
# Stage 1: Build stage
FROM golang:1.23.4-alpine AS builder
```

### 第一阶段：构建阶段
```dockerfile
# 安装必要的包
RUN apk update && apk add --no-cache git ca-certificates tzdata && update-ca-certificates

# 设置工作目录
WORKDIR /app

# 复制依赖文件，利用Docker层缓存
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建静态二进制文件
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o achobeta.server.forge ./cmd
```

**关键参数说明：**
- `CGO_ENABLED=0`: 禁用CGO，生成静态二进制文件
- `-ldflags='-w -s'`: 去除调试信息和符号表，减小文件大小
- `-extldflags "-static"`: 静态链接

### 第二阶段：运行阶段
```dockerfile
FROM alpine:latest

# 安装运行时依赖
RUN apk --no-cache add ca-certificates tzdata

# 创建非root用户（安全最佳实践）
RUN adduser -D -g '' appuser

# 复制构建产物
COPY --from=builder /app/achobeta.server.forge .
COPY --from=builder /app/conf ./conf/

# 设置权限
RUN chmod +x /app/achobeta.server.forge
RUN chown -R appuser:appuser /app

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# 运行应用
CMD ["./achobeta.server.forge"]
```

### 构建优化技巧
1. **利用构建缓存**: 将不经常变化的指令放在前面
2. **最小化层数**: 合并RUN指令
3. **多阶段构建**: 分离构建和运行环境
4. **.dockerignore**: 排除不必要的文件

## 🔧 Docker Compose详解

Docker Compose让我们可以定义和管理多容器应用。

### 基础配置解读
```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: forge_mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: root123456
      MYSQL_DATABASE: fortest
      MYSQL_USER: fortest
      MYSQL_PASSWORD: test
```

**重要配置项：**
- `restart: unless-stopped`: 容器异常退出时自动重启
- `environment`: 设置环境变量
- `volumes`: 数据持久化
- `networks`: 网络配置
- `depends_on`: 服务依赖关系

### 健康检查配置
```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-proot123456"]
  timeout: 20s
  retries: 10
  interval: 30s
```

### 资源限制
```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 1G
    reservations:
      cpus: '0.5'
      memory: 512M
```

### 常用命令
```bash
# 启动所有服务
docker-compose up -d

# 启动指定服务
docker-compose up -d mysql redis

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs app

# 重建服务
docker-compose up -d --build app

# 停止服务
docker-compose down

# 清理数据卷
docker-compose down -v
```

## 🚀 CI/CD流水线详解

我们使用GitHub Actions实现自动化的CI/CD流程。

### CI流程 (.github/workflows/ci.yml)

#### 1. 代码质量检查
```yaml
lint-and-test:
  runs-on: ubuntu-latest
  services:
    mysql: # 启动测试数据库
    redis: # 启动测试缓存

  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-go@v5
    - run: go mod download
    - run: golangci-lint run
    - run: go test -v -race -coverprofile=coverage.out ./...
```

**质量检查包括：**
- 代码风格检查 (golangci-lint)
- 单元测试
- 竞态条件检测 (-race)
- 测试覆盖率

#### 2. 安全扫描
```yaml
security:
  steps:
    - name: Run Gosec Security Scanner
    - name: Run govulncheck  # 漏洞检查
```

#### 3. Docker镜像构建
```yaml
docker-build:
  steps:
    - uses: docker/setup-buildx-action@v3
    - uses: docker/login-action@v3
    - uses: docker/build-push-action@v5
```

**构建优化：**
- 使用BuildKit缓存
- 多平台构建支持
- 自动推送到镜像仓库

### CD流程 (.github/workflows/cd.yml)

#### 1. 测试环境部署
```yaml
deploy-staging:
  if: github.ref == 'refs/heads/master'
  environment: staging

  steps:
    - name: Deploy to staging server
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.STAGING_HOST }}
        script: |
          cd /opt/forge
          git pull origin master
          docker-compose up -d
```

#### 2. 生产环境部署
```yaml
deploy-production:
  if: startsWith(github.ref, 'refs/tags/v')
  environment: production

  steps:
    - name: Build and push release image
    - name: Deploy with rollback capability
```

**部署特点：**
- 基于Git标签触发
- 滚动更新
- 健康检查
- 自动回滚

## 📖 部署指南

### 1. 本地开发环境部署

```bash
# 1. 克隆项目
git clone <your-repo-url>
cd text-achobeta-forge

# 2. 启动基础服务（MySQL + Redis）
docker-compose up -d mysql redis

# 3. 安装Go依赖
go mod download

# 4. 运行应用
go run cmd/main.go
```

### 2. 完整容器化部署

```bash
# 1. 构建并启动所有服务
docker-compose up -d

# 2. 查看服务状态
docker-compose ps

# 3. 查看应用日志
docker-compose logs -f app

# 4. 访问应用
curl http://localhost:8080/health
```

### 3. 生产环境部署

```bash
# 1. 使用生产配置
docker-compose -f docker-compose.prod.yml up -d

# 2. 启用Nginx反向代理
docker-compose -f docker-compose.prod.yml --profile nginx up -d

# 3. 配置SSL证书（Let's Encrypt）
certbot certonly --standalone -d yourdomain.com
```

### 4. 服务器配置

#### 系统要求
- CPU: 2核心以上
- 内存: 4GB以上
- 磁盘: 20GB以上
- 操作系统: Ubuntu 20.04+ / CentOS 8+

#### 安全配置
```bash
# 1. 配置防火墙
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw enable

# 2. 配置Docker用户组
sudo usermod -aG docker $USER

# 3. 设置自动更新
sudo apt install unattended-upgrades
```

### 5. 监控和日志

#### 日志管理
```bash
# 查看容器日志
docker-compose logs -f app

# 查看系统资源使用
docker stats

# 日志轮转配置
sudo vim /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

#### 性能监控
```bash
# 安装htop
sudo apt install htop

# 监控Docker容器
docker exec -it forge_app top

# 数据库性能监控
docker exec -it forge_mysql mysql -u root -p -e "SHOW PROCESSLIST;"
```

## ❓ 常见问题

### 1. 容器启动失败
```bash
# 查看详细错误信息
docker-compose logs app

# 检查端口占用
sudo lsof -i :8080

# 重新构建镜像
docker-compose build --no-cache app
```

### 2. 数据库连接失败
```bash
# 检查MySQL服务状态
docker-compose ps mysql

# 测试数据库连接
docker exec -it forge_mysql mysql -u fortest -p

# 查看数据库日志
docker-compose logs mysql
```

### 3. 镜像构建慢
```bash
# 使用.dockerignore排除不必要的文件
# 清理Docker缓存
docker system prune -f

# 使用镜像加速器
sudo vim /etc/docker/daemon.json
{
  "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"]
}
```

### 4. CI/CD流程失败

#### 测试失败
- 检查测试数据库连接配置
- 确保所有依赖服务正常运行
- 查看测试日志排查具体错误

#### 部署失败
- 检查SSH连接配置
- 验证服务器环境
- 查看部署日志

### 5. 性能问题

#### 应用性能
```bash
# 启用Go性能分析
go tool pprof http://localhost:8080/debug/pprof/profile

# 数据库查询优化
# 查看慢查询日志
docker exec -it forge_mysql tail -f /var/log/mysql/slow.log
```

#### 容器资源
```bash
# 调整容器资源限制
docker-compose -f docker-compose.prod.yml up -d
```

## 🏆 最佳实践

### 1. 安全最佳实践

- **使用非root用户运行容器**
- **定期更新基础镜像**
- **使用多阶段构建减小攻击面**
- **配置健康检查**
- **使用secrets管理敏感信息**

```yaml
# 在GitHub中配置secrets
secrets:
  PROD_HOST: your-server-ip
  PROD_USER: your-username
  PROD_SSH_KEY: your-private-key
```

### 2. 性能最佳实践

- **使用Alpine Linux基础镜像**
- **启用Docker BuildKit缓存**
- **合理配置资源限制**
- **使用连接池优化数据库连接**

### 3. 监控最佳实践

- **配置应用健康检查端点**
- **设置日志轮转防止磁盘满**
- **监控关键指标：CPU、内存、磁盘**
- **设置告警通知**

### 4. 开发最佳实践

- **使用热重载提高开发效率**
- **配置开发环境和生产环境分离**
- **使用代码质量检查工具**
- **编写完善的测试用例**

## 🔄 日常运维

### 备份策略
```bash
# 数据库备份
docker exec forge_mysql mysqldump -u root -proot123456 fortest > backup.sql

# 恢复数据库
docker exec -i forge_mysql mysql -u root -proot123456 fortest < backup.sql

# Redis备份
docker exec forge_redis redis-cli BGSAVE
```

### 更新部署
```bash
# 1. 拉取最新代码
git pull origin master

# 2. 重新构建应用
docker-compose build app

# 3. 滚动更新
docker-compose up -d --no-deps app

# 4. 验证部署
curl http://localhost:8080/health
```

### 扩容
```bash
# 水平扩容应用实例
docker-compose up -d --scale app=3

# 配置负载均衡
# 更新nginx配置支持多实例
```

---

## 📞 支持和帮助

如果在使用过程中遇到问题，可以：

1. 查看本文档的常见问题部分
2. 检查GitHub Issues
3. 查看项目Wiki
4. 联系项目维护者

祝您使用愉快！🎉