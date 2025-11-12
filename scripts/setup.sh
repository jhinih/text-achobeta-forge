#!/bin/bash

# Forge项目快速部署脚本
# 作者: Claude Code Assistant
# 功能: 自动化部署Forge应用

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 未安装，请先安装该工具"
        exit 1
    fi
}

# 检查系统要求
check_requirements() {
    log_step "检查系统要求..."

    check_command docker
    check_command docker-compose
    check_command git

    # 检查Docker服务状态
    if ! systemctl is-active --quiet docker; then
        log_warn "Docker服务未启动，正在启动..."
        sudo systemctl start docker
    fi

    log_info "系统要求检查完成"
}

# 创建必要的目录
create_directories() {
    log_step "创建必要的目录..."

    mkdir -p logs
    mkdir -p data/mysql
    mkdir -p data/redis
    mkdir -p config/ssl

    log_info "目录创建完成"
}

# 设置环境变量
setup_environment() {
    log_step "设置环境变量..."

    if [ ! -f .env ]; then
        cat > .env << EOF
# 应用配置
APP_ENV=development
GIN_MODE=debug
APP_PORT=8080

# 数据库配置
DB_HOST=mysql
DB_PORT=3306
DB_USER=fortest
DB_PASSWORD=test
DB_NAME=fortest

# Redis配置
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=

# JWT密钥
JWT_SECRET=$(openssl rand -base64 32)

# 日志级别
LOG_LEVEL=info
EOF
        log_info "环境配置文件已创建"
    else
        log_info "环境配置文件已存在"
    fi
}

# 构建Docker镜像
build_images() {
    log_step "构建Docker镜像..."

    docker-compose build

    log_info "Docker镜像构建完成"
}

# 启动服务
start_services() {
    log_step "启动服务..."

    # 首先启动基础服务
    docker-compose up -d mysql redis

    # 等待数据库启动
    log_info "等待MySQL启动..."
    until docker-compose exec mysql mysqladmin ping -h"localhost" --silent; do
        sleep 2
    done

    # 等待Redis启动
    log_info "等待Redis启动..."
    until docker-compose exec redis redis-cli ping | grep -q PONG; do
        sleep 1
    done

    # 启动应用服务
    docker-compose up -d app

    log_info "所有服务启动完成"
}

# 运行数据库迁移
run_migrations() {
    log_step "运行数据库迁移..."

    # 检查是否有SQL迁移文件
    if [ -d "sql" ] && [ "$(ls -A sql)" ]; then
        log_info "发现SQL文件，正在执行迁移..."
        for sql_file in sql/*.sql; do
            if [ -f "$sql_file" ]; then
                log_info "执行: $sql_file"
                docker-compose exec mysql mysql -u fortest -ptest fortest < "$sql_file"
            fi
        done
    else
        log_info "未发现SQL迁移文件，跳过数据库迁移"
    fi
}

# 健康检查
health_check() {
    log_step "执行健康检查..."

    # 检查应用健康状态
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8080/health > /dev/null; then
            log_info "应用健康检查通过"
            return 0
        fi

        log_warn "健康检查失败，尝试次数: $attempt/$max_attempts"
        sleep 2
        ((attempt++))
    done

    log_error "应用健康检查失败"
    return 1
}

# 显示服务状态
show_status() {
    log_step "显示服务状态..."

    docker-compose ps

    echo ""
    log_info "服务访问地址:"
    echo "  应用服务: http://localhost:8080"
    echo "  MySQL:   localhost:3306"
    echo "  Redis:   localhost:6379"
    echo ""
    log_info "使用以下命令查看日志:"
    echo "  docker-compose logs -f app"
    echo ""
    log_info "使用以下命令停止服务:"
    echo "  docker-compose down"
}

# 清理函数
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "部署过程中出现错误"
        log_info "使用以下命令查看错误详情:"
        echo "  docker-compose logs"
    fi
}

# 主函数
main() {
    echo "=========================================="
    echo "    Forge 应用部署脚本"
    echo "=========================================="
    echo ""

    # 设置错误处理
    trap cleanup EXIT

    check_requirements
    create_directories
    setup_environment
    build_images
    start_services
    run_migrations

    if health_check; then
        show_status
        echo ""
        log_info "🎉 部署完成！应用已成功启动"
    else
        log_error "🚨 部署失败，请检查错误信息"
        exit 1
    fi
}

# 处理命令行参数
case "${1:-}" in
    "dev")
        export COMPOSE_FILE=docker-compose.yml
        ;;
    "prod")
        export COMPOSE_FILE=docker-compose.prod.yml
        log_warn "使用生产环境配置"
        ;;
    "clean")
        log_step "清理Docker资源..."
        docker-compose down -v
        docker system prune -f
        log_info "清理完成"
        exit 0
        ;;
    "help"|"-h"|"--help")
        echo "用法: $0 [dev|prod|clean|help]"
        echo ""
        echo "选项:"
        echo "  dev     使用开发环境配置部署 (默认)"
        echo "  prod    使用生产环境配置部署"
        echo "  clean   清理Docker资源"
        echo "  help    显示此帮助信息"
        exit 0
        ;;
    "")
        export COMPOSE_FILE=docker-compose.yml
        ;;
    *)
        log_error "未知选项: $1"
        echo "使用 '$0 help' 查看帮助信息"
        exit 1
        ;;
esac

main