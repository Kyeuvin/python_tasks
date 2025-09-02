#!/bin/bash

# =================================
# 任务监控和管理脚本
# 功能：监控后台服务、查看日志、重启异常任务
# 作者：Qoder AI
# 版本：1.0.0
# =================================

set -e

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
    fi
}

# 配置路径
LOGS_DIR="/app/logs"
SYSTEM_LOG_DIR="$LOGS_DIR/system"
PROJECTS_LOG_DIR="$LOGS_DIR/projects"
SERVICES_CONF="$SYSTEM_LOG_DIR/services.conf"
MONITOR_LOG="$SYSTEM_LOG_DIR/task_monitor.log"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-30}"

# 创建必要目录
create_directories() {
    mkdir -p "$SYSTEM_LOG_DIR" "$PROJECTS_LOG_DIR"
    touch "$SERVICES_CONF" "$MONITOR_LOG"
    chmod 755 "$SYSTEM_LOG_DIR" "$PROJECTS_LOG_DIR"
    chmod 644 "$SERVICES_CONF" "$MONITOR_LOG"
}

# 检查Cron服务状态
check_cron_service() {
    if ! pgrep cron > /dev/null; then
        log_error "Cron服务已停止"
        return 1
    fi
    return 0
}

# 重启Cron服务
restart_cron_service() {
    log_warn "尝试重启Cron服务..."
    service cron restart
    sleep 2
    if pgrep cron > /dev/null; then
        log_info "Cron服务重启成功"
        return 0
    else
        log_error "Cron服务重启失败"
        return 1
    fi
}

# 检查后台服务状态
check_background_services() {
    local failed_services=()
    
    if [[ ! -f "$SERVICES_CONF" ]] || [[ ! -s "$SERVICES_CONF" ]]; then
        log_debug "没有注册的后台服务"
        return 0
    fi
    
    while IFS=':' read -r project_name restart_policy command; do
        # 跳过空行和注释
        [[ -z "$project_name" || "$project_name" =~ ^# ]] && continue
        
        local pid_file="$PROJECTS_LOG_DIR/${project_name}.pid"
        local log_file="$PROJECTS_LOG_DIR/${project_name}.log"
        
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file" 2>/dev/null)
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                log_debug "服务 $project_name 运行正常 (PID: $pid)"
            else
                log_warn "服务 $project_name 已停止 (PID: $pid)"
                failed_services+=("$project_name:$restart_policy:$command")
            fi
        else
            log_warn "服务 $project_name 的PID文件不存在"
            failed_services+=("$project_name:$restart_policy:$command")
        fi
    done < "$SERVICES_CONF"
    
    # 重启失败的服务
    for service_info in "${failed_services[@]}"; do
        IFS=':' read -r project_name restart_policy command <<< "$service_info"
        
        case "$restart_policy" in
            "always"|"on-failure")
                restart_background_service "$project_name" "$command" "$restart_policy"
                ;;
            "never")
                log_info "服务 $project_name 重启策略为 'never'，跳过重启"
                ;;
            *)
                log_warn "服务 $project_name 重启策略 '$restart_policy' 未知"
                ;;
        esac
    done
}

# 重启后台服务
restart_background_service() {
    local project_name="$1"
    local command="$2"
    local restart_policy="$3"
    local log_file="$PROJECTS_LOG_DIR/${project_name}.log"
    local pid_file="$PROJECTS_LOG_DIR/${project_name}.pid"
    
    log_info "重启后台服务: $project_name"
    
    # 停止旧进程（如果还在运行）
    if [[ -f "$pid_file" ]]; then
        local old_pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null || true
            sleep 2
        fi
    fi
    
    # 启动新进程
    nohup bash -c "$command" >> "$log_file" 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$pid_file"
    
    # 验证启动成功
    sleep 1
    if kill -0 "$new_pid" 2>/dev/null; then
        log_info "服务 $project_name 重启成功 (PID: $new_pid)"
        echo "$(date): 重启服务 $project_name PID:$new_pid" >> "$MONITOR_LOG"
        return 0
    else
        log_error "服务 $project_name 重启失败"
        return 1
    fi
}

# 监控守护进程
daemon_monitor() {
    log_info "启动监控守护进程 (间隔: ${MONITOR_INTERVAL}秒)"
    
    while true; do
        # 检查Cron服务
        if ! check_cron_service; then
            restart_cron_service
        fi
        
        # 检查后台服务
        check_background_services
        
        # 等待下次检查
        sleep "$MONITOR_INTERVAL"
    done
}

# 显示所有任务状态
show_status() {
    echo "==================== 系统状态 ===================="
    
    # Cron服务状态
    echo "Cron服务状态:"
    if pgrep cron > /dev/null; then
        echo "  ✓ 运行中"
    else
        echo "  ✗ 已停止"
    fi
    
    # 定时任务列表
    echo
    echo "定时任务列表:"
    local cron_tasks=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | grep -v "^SHELL\\|^PATH\\|^HOME\\|^PYTHON")
    if [[ -n "$cron_tasks" ]]; then
        echo "$cron_tasks" | while read -r line; do
            if [[ -n "$line" ]]; then
                echo "  - $line"
            fi
        done
    else
        echo "  (无定时任务)"
    fi
    
    # 后台服务状态
    echo
    echo "后台服务状态:"
    if [[ -f "$SERVICES_CONF" ]] && [[ -s "$SERVICES_CONF" ]]; then
        while IFS=':' read -r project_name restart_policy command; do
            # 跳过空行和注释
            [[ -z "$project_name" || "$project_name" =~ ^# ]] && continue
            
            local pid_file="$PROJECTS_LOG_DIR/${project_name}.pid"
            if [[ -f "$pid_file" ]]; then
                local pid=$(cat "$pid_file" 2>/dev/null)
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    echo "  ✓ $project_name (PID: $pid) [$restart_policy]"
                else
                    echo "  ✗ $project_name (已停止) [$restart_policy]"
                fi
            else
                echo "  ? $project_name (PID文件不存在) [$restart_policy]"
            fi
        done < "$SERVICES_CONF"
    else
        echo "  (无后台服务)"
    fi
    
    # 监控器状态
    echo
    echo "监控器状态:"
    local monitor_pid_file="$SYSTEM_LOG_DIR/monitor.pid"
    if [[ -f "$monitor_pid_file" ]]; then
        local monitor_pid=$(cat "$monitor_pid_file" 2>/dev/null)
        if [[ -n "$monitor_pid" ]] && kill -0 "$monitor_pid" 2>/dev/null; then
            echo "  ✓ 运行中 (PID: $monitor_pid)"
        else
            echo "  ✗ 已停止"
        fi
    else
        echo "  ✗ 未启动"
    fi
    
    echo "================================================="
}

# 查看项目日志
show_logs() {
    local project_name="$1"
    local lines="${2:-50}"
    
    if [[ -z "$project_name" ]]; then
        log_error "请指定项目名称"
        return 1
    fi
    
    local log_file="$PROJECTS_LOG_DIR/${project_name}.log"
    if [[ ! -f "$log_file" ]]; then
        log_error "项目 $project_name 的日志文件不存在: $log_file"
        return 1
    fi
    
    echo "==================== $project_name 日志 (最近 $lines 行) ===================="
    tail -n "$lines" "$log_file"
    echo "================================================================"
}

# 实时跟踪项目日志
follow_logs() {
    local project_name="$1"
    
    if [[ -z "$project_name" ]]; then
        log_error "请指定项目名称"
        return 1
    fi
    
    local log_file="$PROJECTS_LOG_DIR/${project_name}.log"
    if [[ ! -f "$log_file" ]]; then
        log_error "项目 $project_name 的日志文件不存在: $log_file"
        return 1
    fi
    
    echo "实时跟踪 $project_name 日志 (按Ctrl+C退出)..."
    tail -f "$log_file"
}

# 手动重启项目
restart_project() {
    local project_name="$1"
    
    if [[ -z "$project_name" ]]; then
        log_error "请指定项目名称"
        return 1
    fi
    
    # 使用项目管理器重启
    if [[ -f "/app/scripts/project_manager.sh" ]]; then
        /app/scripts/project_manager.sh restart "$project_name"
    else
        log_error "项目管理器脚本不存在"
        return 1
    fi
}

# 系统健康检查
health_check() {
    local issues=0
    
    echo "==================== 系统健康检查 ===================="
    
    # 检查Cron服务
    if check_cron_service; then
        echo "✓ Cron服务运行正常"
    else
        echo "✗ Cron服务异常"
        ((issues++))
    fi
    
    # 检查磁盘空间
    local disk_usage=$(df /app | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ "$disk_usage" -lt 90 ]]; then
        echo "✓ 磁盘空间充足 ($disk_usage%)"
    else
        echo "✗ 磁盘空间不足 ($disk_usage%)"
        ((issues++))
    fi
    
    # 检查日志目录
    if [[ -d "$PROJECTS_LOG_DIR" && -w "$PROJECTS_LOG_DIR" ]]; then
        echo "✓ 日志目录可写"
    else
        echo "✗ 日志目录不可写"
        ((issues++))
    fi
    
    # 检查后台服务
    local service_count=0
    local running_count=0
    
    if [[ -f "$SERVICES_CONF" ]] && [[ -s "$SERVICES_CONF" ]]; then
        while IFS=':' read -r project_name restart_policy command; do
            [[ -z "$project_name" || "$project_name" =~ ^# ]] && continue
            ((service_count++))
            
            local pid_file="$PROJECTS_LOG_DIR/${project_name}.pid"
            if [[ -f "$pid_file" ]]; then
                local pid=$(cat "$pid_file" 2>/dev/null)
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    ((running_count++))
                fi
            fi
        done < "$SERVICES_CONF"
    fi
    
    if [[ $service_count -eq 0 ]]; then
        echo "ℹ 无注册的后台服务"
    elif [[ $running_count -eq $service_count ]]; then
        echo "✓ 所有后台服务运行正常 ($running_count/$service_count)"
    else
        echo "⚠ 部分后台服务异常 ($running_count/$service_count 运行中)"
        ((issues++))
    fi
    
    echo "================================================="
    
    if [[ $issues -eq 0 ]]; then
        echo "✓ 系统健康状态良好"
        return 0
    else
        echo "⚠ 发现 $issues 个问题"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
任务监控和管理脚本 v1.0.0

用法: $0 <command> [options]

命令:
  daemon                      启动监控守护进程
  status                      显示所有任务状态
  logs <project_name> [lines] 查看项目日志 (默认50行)
  follow <project_name>       实时跟踪项目日志
  restart <project_name>      重启指定项目
  health                      系统健康检查
  help                        显示帮助信息

示例:
  $0 daemon
  $0 status
  $0 logs task1 100
  $0 follow task1
  $0 restart task1
  $0 health

环境变量:
  MONITOR_INTERVAL=30         监控检查间隔（秒）
  DEBUG=true                  启用调试输出

更多信息请查看项目文档。
EOF
}

# 主函数
main() {
    local command="$1"
    shift || true
    
    # 创建必要目录
    create_directories
    
    case "$command" in
        "daemon")
            daemon_monitor
            ;;
        "status")
            show_status
            ;;
        "logs")
            local project_name="$1"
            local lines="${2:-50}"
            show_logs "$project_name" "$lines"
            ;;
        "follow")
            local project_name="$1"
            follow_logs "$project_name"
            ;;
        "restart")
            local project_name="$1"
            restart_project "$project_name"
            ;;
        "health")
            health_check
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            echo
            show_help
            return 1
            ;;
    esac
}

# 执行主函数
main "$@"