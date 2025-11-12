# 🚀 简化版Docker CI/CD指南

## 🎯 简化版本说明

这是一个精简的Docker CI/CD配置，去掉了复杂的功能，专注于核心的Docker构建和推送功能。

## 📋 配置文件

### GitHub Actions工作流 (.github/workflows/docker.yml)

```yaml
name: Docker Image CI

on:
  push:
    branches: [ "master" ] #当有push到master分支时

jobs:
  build:
    runs-on: ubuntu-latest #运行在虚拟机环境 ubuntu-latest
    steps:
      - uses: actions/checkout@v3 #获取源码
      - name: Build the Docker image #构建Docker镜像
        run: | #开始运行
          docker login -u jhinih -p ${{ secrets.DOCKER_HUB_PASSWORD }} #登录docker hub
          docker buildx create --use #使用docker buildx
          docker buildx build . --push --tag jhinih/text-achobeta-forge:latest #构建并推送
```

### Dockerfile

```dockerfile
# 多阶段构建 - 构建阶段
FROM golang:1.23.4-alpine AS builder

# 安装必要的包和工具
RUN apk update && apk add --no-cache git ca-certificates tzdata && update-ca-certificates

# 设置工作目录
WORKDIR /app

# 复制依赖文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码并构建
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o achobeta.server.forge ./cmd

# 运行阶段
FROM alpine:latest

# 安装必要的包，包含curl用于健康检查
RUN apk --no-cache add ca-certificates tzdata curl

# 创建非root用户
RUN adduser -D -g '' appuser

WORKDIR /app

# 复制构建的二进制文件和配置文件
COPY --from=builder /app/achobeta.server.forge .
COPY --from=builder /app/conf ./conf/
COPY --from=builder /app/template ./template/

RUN chmod +x /app/achobeta.server.forge
RUN chown -R appuser:appuser /app

USER appuser
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["./achobeta.server.forge"]
```

## 🔧 使用步骤

### 1. 配置GitHub Secrets

在你的GitHub仓库设置中添加：

```
DOCKER_HUB_PASSWORD=你的Docker Hub密码或访问令牌
```

**获取Docker Hub访问令牌：**
1. 登录 [Docker Hub](https://hub.docker.com/)
2. 点击右上角头像 → Account Settings
3. Security → New Access Token
4. 创建Token并复制（只会显示一次）

### 2. 推送代码触发构建

```bash
# 推送到master分支会自动触发构建
git add .
git commit -m "trigger docker build"
git push origin master
```

### 3. 检查构建状态

- 在GitHub仓库的Actions页签查看构建进度
- 构建成功后，镜像会自动推送到Docker Hub

### 4. 使用构建的镜像

```bash
# 拉取镜像
docker pull jhinih/text-achobeta-forge:latest

# 运行容器
docker run -p 8080:8080 jhinih/text-achobeta-forge:latest
```

## 🐛 常见问题

### 1. 构建失败
- 检查Dockerfile语法
- 确保go.mod文件存在
- 检查源代码能否正常编译

### 2. 推送失败
- 检查DOCKER_HUB_PASSWORD是否正确配置
- 确认Docker Hub仓库名称正确
- 检查网络连接

### 3. 权限问题
```bash
# 如果遇到权限问题，可以在Dockerfile中添加：
RUN chmod +x /app/achobeta.server.forge
USER appuser
```

## 📊 简化版 vs 完整版

| 功能 | 简化版 | 完整版 |
|------|--------|--------|
| Docker构建 | ✅ | ✅ |
| 推送到Docker Hub | ✅ | ✅ |
| 代码质量检查 | ❌ | ✅ |
| 安全扫描 | ❌ | ✅ |
| 自动测试 | ❌ | ✅ |
| 多环境部署 | ❌ | ✅ |
| 多平台构建 | ❌ | ✅ |

## 🚀 下一步

如果你需要更完整的功能，可以参考：
- [DOCKER_CICD_GUIDE.md](./DOCKER_CICD_GUIDE.md) - 完整版指南
- [QUICK_START.md](./QUICK_START.md) - 快速开始指南

## 💡 提示

这个简化版本适合：
- 新手学习Docker CI/CD
- 小型项目快速部署
- 不需要复杂功能的简单应用

如果项目需要生产环境部署或更严格的质量控制，建议升级到完整版配置。