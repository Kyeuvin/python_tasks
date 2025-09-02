#!/bin/bash

# =================================
# Docker容器入口脚本
# 功能：启动cron服务并配置定时任务
# =================================

set -e

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 设置默认环境变量
export TIMEZONE=${TIMEZONE:-"Asia/Shanghai"}
export LOG_LEVEL=${LOG_LEVEL:-"INFO"}

log_info "容器启动中..."
log_info "时区设置: $TIMEZONE"
log_info "日志级别: $LOG_LEVEL"

# 设置时区
if [ ! -z "$TIMEZONE" ]; then
    ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    echo $TIMEZONE > /etc/timezone
    log_info "时区已设置为: $TIMEZONE"
fi

# 配置路径
PROJECTS_DIR="/app"
LOGS_DIR="/app/logs"
SYSTEM_LOG_DIR="$LOGS_DIR/system"
PROJECTS_LOG_DIR="$LOGS_DIR/projects"
REGISTRATION_LOG="$SYSTEM_LOG_DIR/registration.log"
SERVICES_CONF="$SYSTEM_LOG_DIR/services.conf"

# 创建必要的目录
create_directories() {
    mkdir -p "$SYSTEM_LOG_DIR" "$PROJECTS_LOG_DIR"
    touch "$REGISTRATION_LOG" "$SERVICES_CONF"
    chmod 755 "$SYSTEM_LOG_DIR" "$PROJECTS_LOG_DIR"
    chmod 644 "$REGISTRATION_LOG" "$SERVICES_CONF"
}


# 设置文件权限
if [[ -f "/app/scripts/setup_permissions.sh" ]]; then
    bash /app/scripts/setup_permissions.sh
fi

# 设置日志文件权限
chmod 666 /app/logs/*.log

log_info "初始化基础 crontab 配置..."

# 生成基础crontab配置（只包含环境变量）
cat > /tmp/crontab << EOF
# ====Docker容器定时任务配置====
# 生成时间: $(date)
# ==========环境变量===========
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
HOME=/root
PYTHONUNBUFFERED=1
# =============================

EOF

# 安装基础crontab
crontab /tmp/crontab

log_info "基础 crontab 配置完成"

# 启动cron服务
log_info "启动cron服务..."
service cron start

# 检查cron服务状态
if pgrep cron > /dev/null; then
    log_info "cron服务启动成功"
else
    log_error "cron服务启动失败"
    exit 1
fi

# 执行自动项目发现和注册
log_info "开始自动项目发现和注册..."
if [[ -f "/app/scripts/scan_and_add.sh" ]]; then
    chmod +x /app/scripts/scan_and_add.sh
    chmod +x /app/scripts/*.sh 2>/dev/null || true
    
    # 显示发现的项目
    log_info "正在扫描项目目录..."
    
    # 执行项目扫描和注册
    if /app/scripts/scan_and_add.sh 2>&1; then
        log_info "项目自动注册完成"
    else
        log_warn "项目自动注册失败，尝试备用方案..."
        
        # 备用方案：使用简化注册脚本
        if [[ -f "/app/scripts/simple_register.sh" ]]; then
            chmod +x /app/scripts/simple_register.sh
            for project_dir in /app/*/; do
                if [[ -d "$project_dir" ]]; then
                    project_name=$(basename "$project_dir")
                    if [[ "$project_name" =~ ^(logs|scripts|data|backup)$ ]]; then
                        continue
                    fi
                    if [[ -f "$project_dir/setup.sh" ]]; then
                        log_info "尝试注册项目: $project_name"
                        /app/scripts/simple_register.sh "$project_name" || log_warn "项目 $project_name 注册失败"
                    fi
                fi
            done
        fi
    fi
else
    log_error "项目扫描脚本不存在: /app/scripts/scan_and_add.sh"
fi

# 显示当前注册的任务
log_info "当前已注册的定时任务:"
crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | grep -v "^SHELL\|^PATH\|^HOME\|^PYTHON" || log_info "  (无定时任务)"

# 创建健康检查监听
log_info "启动健康检查监听..."
nohup bash -c 'while true; do echo -e "HTTP/1.1 200 OK\n\nHealthy" | nc -l -p 8080 -q 1; done' &

# 启动任务监控器（用于监控后台服务）
log_info "启动任务监控器..."
if [[ -f "/app/scripts/task_monitor.sh" ]]; then
    chmod +x /app/scripts/task_monitor.sh
    nohup /app/scripts/task_monitor.sh daemon >> /app/logs/system/task_monitor.log 2>&1 &
    MONITOR_PID=$!
    log_info "任务监控器已启动，PID: $MONITOR_PID"
    echo $MONITOR_PID > /app/logs/system/monitor.pid
else
    log_warn "任务监控器脚本不存在，后台服务监控功能不可用"
fi

# 输出启动信息
log_info "============================================"
log_info "定时任务容器启动完成"
log_info "容器名称: $HOSTNAME"
log_info "启动时间: $(date)"
log_info "Python版本: $(python3 --version 2>/dev/null || echo 'Python3 not found')"
log_info "============================================"

# 保持容器运行并监控cron服务
log_info "监控cron服务状态..."

# 定期检查cron服务并输出日志
while true; do
    if ! pgrep cron > /dev/null; then
        log_error "cron服务已停止，尝试重启..."
        service cron start
        sleep 5
        if pgrep cron > /dev/null; then
            log_info "cron服务重启成功"
        else
            log_error "cron服务重启失败，退出容器"
            exit 1
        fi
    fi
    
    # 检查任务监控器是否还在运行
    if [ -f "/app/logs/system/monitor.pid" ]; then
        MONITOR_PID=$(cat /app/logs/system/monitor.pid)
        if ! kill -0 $MONITOR_PID 2>/dev/null; then
            log_warn "任务监控器已停止，尝试重启..."
            if [[ -f "/app/scripts/task_monitor.sh" ]]; then
                nohup /app/scripts/task_monitor.sh daemon >> /app/logs/system/task_monitor.log 2>&1 &
                NEW_PID=$!
                echo $NEW_PID > /app/logs/system/monitor.pid
                log_info "任务监控器已重启，新PID: $NEW_PID"
            fi
        fi
    fi
    
    # 每30秒检查一次
    sleep 30
done