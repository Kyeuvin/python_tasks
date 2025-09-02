#!/bin/bash

# 项目注册脚本

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
    fi
}

# 配置路径
PROJECTS_DIR="/app"
LOGS_DIR="/app/logs"
SYSTEM_LOG_DIR="$LOGS_DIR/system"
PROJECTS_LOG_DIR="$LOGS_DIR/projects"
REGISTRATION_LOG="$SYSTEM_LOG_DIR/registration.log"
SERVICES_CONF="$SYSTEM_LOG_DIR/services.conf"

# 验证setup.sh脚本格式
validate_setup_script() {
    local project_name="$1"
    local setup_file="$PROJECTS_DIR/$project_name/setup.sh"
    
    log_debug "验证项目 $project_name 的setup.sh脚本格式"
    
    # 检查文件是否可执行
    if [[ ! -x "$setup_file" ]]; then
        log_warn "setup.sh文件不可执行，尝试添加执行权限"
        chmod +x "$setup_file"
    fi
    
    # 检查脚本语法
    if ! bash -n "$setup_file" 2>/dev/null; then
        log_error "项目 $project_name 的setup.sh语法错误"
        return 1
    fi
    
    return 0
}

# 执行项目的依赖检查
check_project_dependencies() {
    local project_name="$1"
    local project_dir="$PROJECTS_DIR/$project_name"
    
    log_debug "检查项目 $project_name 的依赖"
    
    # 进入项目目录并source setup.sh，然后调用依赖检查函数
    (
        cd "$project_dir"
        source ./setup.sh >/dev/null 2>&1
        
        # 如果存在check_dependencies函数，则调用它
        if declare -f check_dependencies > /dev/null; then
            if ! check_dependencies >/dev/null 2>&1; then
                echo "项目 $project_name 依赖检查失败" >&2
                exit 1
            fi
        fi
        
        exit 0
    )
}

# 执行项目初始化
initialize_project() {
    local project_name="$1"
    local project_dir="$PROJECTS_DIR/$project_name"
    
    log_debug "初始化项目: $project_name"
    
    # 进入项目目录并source setup.sh，然后调用初始化函数
    (
        cd "$project_dir"
        source ./setup.sh >/dev/null 2>&1
        
        # 如果存在initialize函数，则调用它
        if declare -f initialize > /dev/null; then
            if ! initialize >/dev/null 2>&1; then
                echo "项目 $project_name 初始化失败" >&2
                exit 1
            fi
        fi
        
        exit 0
    )
}

# 注册后台服务
register_background_service() {
    local project_name="$1"
    local command="$2"
    local restart_policy="${3:-always}"
    local log_file="$PROJECTS_LOG_DIR/${project_name}.log"
    local pid_file="$PROJECTS_LOG_DIR/${project_name}.pid"
    
    log_info "注册后台服务: $project_name"
    log_debug "  命令: $command"
    log_debug "  重启策略: $restart_policy"
    log_debug "  日志: $log_file"
    log_debug "  PID文件: $pid_file"
    
    # 确保日志文件存在
    touch "$log_file"
    chmod 666 "$log_file"
    
    # 检查是否已存在运行中的服务
    if [[ -f "$pid_file" ]]; then
        local old_pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            log_warn "项目 $project_name 的后台服务已运行 (PID: $old_pid)，跳过启动"
            return 0
        fi
    fi
    
    # 启动后台服务
    nohup bash -c "$command" >> "$log_file" 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$pid_file"
    
    # 添加到监控列表
    echo "$project_name:$restart_policy:$command" >> "$SERVICES_CONF"
    
    # 记录注册信息
    echo "$(date): SERVICE注册 $project_name PID:$new_pid" >> "$REGISTRATION_LOG"
    log_info "后台服务注册成功: $project_name (PID: $new_pid)"
    
    return 0
}

# 直接注册单个项目的函数
register_single_project() {
    local project_name="$1"
    local project_dir="/app/$project_name"
    local setup_file="$project_dir/setup.sh"
    
    log_info "注册项目: $project_name"
    
    # 检查项目是否存在
    if [[ ! -d "$project_dir" ]]; then
        log_error "项目目录不存在: $project_dir"
        return 1
    fi
    
    if [[ ! -f "$setup_file" ]]; then
        log_error "setup.sh文件不存在: $setup_file"
        return 1
    fi

    # 验证setup.sh脚本
    if ! validate_setup_script "$project_name"; then
        log_error "项目 $project_name 的setup.sh验证失败"
        return 1
    fi

    # 检查项目依赖
    if ! check_project_dependencies "$project_name"; then
        log_error "项目 $project_name 的项目依赖验证失败"
        return 1
    fi

    # 项目初始化
    if ! initialize_project "$project_name"; then
        log_error "项目 $project_name 的初始化失败"
        return 1
    fi
    
    # 进入项目目录并读取配置
    log_info "读取项目配置..."
    
    # 在子shell中执行cd和source操作，避免改变父shell的工作目录
    local project_config
    project_config=$(
        cd "$project_dir"
        source ./setup.sh >/dev/null 2>&1
        echo "PROJECT_NAME=${PROJECT_NAME:-$project_name}"
        echo "PROJECT_TYPE=${PROJECT_TYPE:-cron}"
        echo "CRON_SCHEDULE=${CRON_SCHEDULE:-}"
        echo "CRON_COMMAND=${CRON_COMMAND:-}"
        echo "SERVICE_COMMAND=${SERVICE_COMMAND:-}"
        echo "SERVICE_RESTART_POLICY=${SERVICE_RESTART_POLICY:-always}"
    )
    
    # 安全解析配置
    local PROJECT_NAME PROJECT_TYPE CRON_SCHEDULE CRON_COMMAND SERVICE_COMMAND SERVICE_RESTART_POLICY
    while IFS='=' read -r key value; do
        case "$key" in
            "PROJECT_NAME") PROJECT_NAME="$value" ;;
            "PROJECT_TYPE") PROJECT_TYPE="$value" ;;
            "CRON_SCHEDULE") CRON_SCHEDULE="$value" ;;
            "CRON_COMMAND") CRON_COMMAND="$value" ;;
            "SERVICE_COMMAND") SERVICE_COMMAND="$value" ;;
            "SERVICE_RESTART_POLICY") SERVICE_RESTART_POLICY="$value" ;;
        esac
    done <<< "$project_config"
    
    log_info "项目配置:"
    echo "  名称: $PROJECT_NAME"
    echo "  类型: $PROJECT_TYPE"
    
    # 根据项目类型处理
    case "$PROJECT_TYPE" in
        "cron")
            if [[ -z "$CRON_SCHEDULE" || -z "$CRON_COMMAND" ]]; then
                log_error "定时任务配置不完整"
                echo "  CRON_SCHEDULE: '$CRON_SCHEDULE'"
                echo "  CRON_COMMAND: '$CRON_COMMAND'"
                return 1
            fi
            
            echo "  调度: $CRON_SCHEDULE"
            echo "  命令: $CRON_COMMAND"
            
            # 创建日志目录和文件
            mkdir -p /app/logs/projects
            local log_file="/app/logs/projects/${project_name}.log"
            touch "$log_file"
            chmod 666 "$log_file"
            
            # 检查是否已存在并彻底清理
            if crontab -l 2>/dev/null | grep -q "# PROJECT: $project_name"; then
                log_warn "项目已在crontab中，先移除所有旧配置"
                # 更彻底的清理：移除项目注释和所有相关命令行
                log_info "正在清理旧的crontab配置..."
                crontab -l 2>/dev/null | grep -v "# PROJECT: $project_name" | grep -v "/app/$project_name" | crontab -
                log_info "旧配置清理完成"
            fi
            
            log_info "正在添加新的crontab配置..."
            
            # 添加到crontab - 使用更可靠的方法
            {
                # 检查是否已有环境变量设置
                if ! crontab -l 2>/dev/null | grep -q "SHELL="; then
                    # 添加必要的环境变量
                    echo "SHELL=/bin/bash"
                    echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
                    echo "HOME=/root"
                    echo ""
                fi
                crontab -l 2>/dev/null | grep -v "^SHELL=" | grep -v "^PATH=" | grep -v "^HOME=" || true
                echo "# PROJECT: $project_name"
                echo "$CRON_SCHEDULE $CRON_COMMAND >> $log_file 2>&1"
            } | crontab -
            
            log_info "crontab操作完成"
            
            # 验证添加是否成功
            log_info "验证crontab注册结果..."
            if crontab -l 2>/dev/null | grep -q "# PROJECT: $project_name"; then
                log_info "定时任务注册成功"
            else
                log_error "定时任务注册失败"
                return 1
            fi
            ;;
            
        "service")
            if [[ -z "$SERVICE_COMMAND" ]]; then
                log_error "项目 $project_name 的SERVICE_COMMAND配置为空"
                return 1
            fi
            
            # 调用注册后台服务函数
            log_debug "开始注册后台服务..."
            if register_background_service "$project_name" "$SERVICE_COMMAND" "$SERVICE_RESTART_POLICY"; then
                log_info "项目 $project_name 注册成功"
                log_debug "后台服务注册成功"
                return 0
            else
                log_error "项目 $project_name 注册失败"
                log_debug "后台服务注册失败"
                return 1
            fi
            ;;
        *)
            log_error "不支持的项目类型: $PROJECT_TYPE"
            return 1
            ;;
    esac
    
    log_info "register_single_project函数完成: $project_name"
    return 0
}

# 主函数
main() {
    local project_name="$1"
    
    if [[ -z "$project_name" ]]; then
        echo "用法: $0 <项目名称>"
        echo "示例: $0 abc"
        return 1
    fi
    
    register_single_project "$project_name"
}

main "$@"