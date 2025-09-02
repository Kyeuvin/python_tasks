#!/bin/bash

# =================================
# 自动脚本执行管理器
# 功能：项目发现、注册和管理
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
PROJECTS_DIR="/app"
LOGS_DIR="/app/logs"
SYSTEM_LOG_DIR="$LOGS_DIR/system"
PROJECTS_LOG_DIR="$LOGS_DIR/projects"
REGISTRATION_LOG="$SYSTEM_LOG_DIR/registration.log"
SERVICES_CONF="$SYSTEM_LOG_DIR/services.conf"

# 创建必要目录
create_directories() {
    mkdir -p "$SYSTEM_LOG_DIR" "$PROJECTS_LOG_DIR"
    touch "$REGISTRATION_LOG" "$SERVICES_CONF"
    chmod 755 "$SYSTEM_LOG_DIR" "$PROJECTS_LOG_DIR"
    chmod 644 "$REGISTRATION_LOG" "$SERVICES_CONF"
}


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

# 扫描项目目录，查找包含setup.sh的项目
scan_projects() {
    log_debug "开始扫描项目目录: $PROJECTS_DIR" >&2
    local discovered_projects=()
    
    for project_dir in "$PROJECTS_DIR"/*/; do
        if [[ -d "$project_dir" ]]; then
            local project_name=$(basename "$project_dir")
            local setup_file="$project_dir/setup.sh"
            
            # 跳过系统目录
            if [[ "$project_name" =~ ^(logs|scripts|data|backup)$ ]]; then
                log_debug "跳过系统目录: $project_name" >&2
                continue
            fi
            
            if [[ -f "$setup_file" ]]; then
                log_debug "发现项目: $project_name (setup.sh存在)" >&2
                discovered_projects+=("$project_name")
            else
                log_debug "项目 $project_name 没有setup.sh文件，跳过" >&2
            fi
        fi
    done
    
    if [[ ${#discovered_projects[@]} -eq 0 ]]; then
        log_debug "未发现任何包含setup.sh的项目" >&2
    else
        log_debug "共发现 ${#discovered_projects[@]} 个项目: ${discovered_projects[*]}" >&2
    fi
    
    # 只输出项目名称数组，不包含任何log信息
    echo "${discovered_projects[@]}"
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

# 移除项目
remove_project() {
    local project_name="$1"
    
    log_info "移除项目: $project_name"
    
    # 移除定时任务
    if crontab -l 2>/dev/null | grep -q "# PROJECT: $project_name"; then
        # 更彻底的清理：移除项目注释和所有相关命令行
        crontab -l 2>/dev/null | grep -v "# PROJECT: $project_name" | grep -v "/app/$project_name" | crontab -
        log_info "已移除项目 $project_name 的所有定时任务"
    fi
    
    # 停止后台服务
    local pid_file="$PROJECTS_LOG_DIR/${project_name}.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_info "已停止项目 $project_name 的后台服务 (PID: $pid)"
        fi
        rm -f "$pid_file"
    fi
    
    # 从监控列表移除
    if [[ -f "$SERVICES_CONF" ]]; then
        grep -v "^$project_name:" "$SERVICES_CONF" > "$SERVICES_CONF.tmp" && mv "$SERVICES_CONF.tmp" "$SERVICES_CONF"
    fi
    
    # 记录移除操作
    echo "$(date): 移除项目 $project_name" >> "$REGISTRATION_LOG"
    
    return 0
}

# 列出所有项目
list_projects() {
    log_info "项目列表:"
    
    # 扫描并显示项目
    local projects
    projects=($(scan_projects))
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        echo "  (无项目)"
        return 0
    fi
    
    for project in "${projects[@]}"; do
        local status="未知"
        local type="未知"
        
        # 检查项目类型和状态
        local project_dir="$PROJECTS_DIR/$project"
        if [[ -f "$project_dir/setup.sh" ]]; then
            local project_config
            project_config=$(
                cd "$project_dir"
                {
                    source ./setup.sh >/dev/null 2>&1
                    echo "PROJECT_TYPE=${PROJECT_TYPE:-cron}"
                }
            )
            # 安全解析 PROJECT_TYPE
            while IFS='=' read -r key value; do
                if [[ "$key" == "PROJECT_TYPE" ]]; then
                    type="$value"
                    break
                fi
            done <<< "$project_config"
            
            case "$type" in
                "cron")
                    if crontab -l 2>/dev/null | grep -q "# PROJECT: $project"; then
                        status="已注册"
                    else
                        status="未注册"
                    fi
                    ;;
                "service")
                    local pid_file="$PROJECTS_LOG_DIR/${project}.pid"
                    if [[ -f "$pid_file" ]]; then
                        local pid=$(cat "$pid_file" 2>/dev/null)
                        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                            status="运行中 (PID: $pid)"
                        else
                            status="已停止"
                        fi
                    else
                        status="未注册"
                    fi
                    ;;
            esac
        fi
        
        echo "  - $project [$type] ($status)"
    done
}

# 查看项目状态
project_status() {
    local project_name="$1"
    
    if [[ -z "$project_name" ]]; then
        log_error "请指定项目名称"
        return 1
    fi
    
    local project_dir="$PROJECTS_DIR/$project_name"
    if [[ ! -d "$project_dir" ]]; then
        log_error "项目 $project_name 不存在"
        return 1
    fi
    
    if [[ ! -f "$project_dir/setup.sh" ]]; then
        log_error "项目 $project_name 没有setup.sh文件"
        return 1
    fi
    
    log_info "项目 $project_name 状态:"
    
    # 获取项目配置
    local project_config
    project_config=$(
        cd "$project_dir"
        source ./setup.sh
        echo "PROJECT_NAME=${PROJECT_NAME:-$project_name}"
        echo "PROJECT_TYPE=${PROJECT_TYPE:-cron}"
        echo "CRON_SCHEDULE=${CRON_SCHEDULE:-}"
        echo "CRON_COMMAND=${CRON_COMMAND:-}"
        echo "SERVICE_COMMAND=${SERVICE_COMMAND:-}"
    )
    # 安全解析配置
    local PROJECT_NAME PROJECT_TYPE CRON_SCHEDULE CRON_COMMAND SERVICE_COMMAND
    while IFS='=' read -r key value; do
        case "$key" in
            "PROJECT_NAME")
                PROJECT_NAME="$value"
                ;;
            "PROJECT_TYPE")
                PROJECT_TYPE="$value"
                ;;
            "CRON_SCHEDULE")
                CRON_SCHEDULE="$value"
                ;;
            "CRON_COMMAND")
                CRON_COMMAND="$value"
                ;;
            "SERVICE_COMMAND")
                SERVICE_COMMAND="$value"
                ;;
        esac
    done <<< "$project_config"
    
    echo "  项目名称: $PROJECT_NAME"
    echo "  项目类型: $PROJECT_TYPE"
    
    case "$PROJECT_TYPE" in
        "cron")
            echo "  调度规则: $CRON_SCHEDULE"
            echo "  执行命令: $CRON_COMMAND"
            if crontab -l 2>/dev/null | grep -q "# PROJECT: $project_name"; then
                echo "  状态: 已注册到crontab"
            else
                echo "  状态: 未注册"
            fi
            ;;
        "service")
            echo "  执行命令: $SERVICE_COMMAND"
            local pid_file="$PROJECTS_LOG_DIR/${project_name}.pid"
            if [[ -f "$pid_file" ]]; then
                local pid=$(cat "$pid_file" 2>/dev/null)
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    echo "  状态: 运行中 (PID: $pid)"
                else
                    echo "  状态: 已停止"
                fi
            else
                echo "  状态: 未注册"
            fi
            ;;
    esac
    
    # 显示日志文件信息
    local log_file="$PROJECTS_LOG_DIR/${project_name}.log"
    if [[ -f "$log_file" ]]; then
        local log_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
        local log_lines=$(wc -l < "$log_file" 2>/dev/null || echo "0")
        echo "  日志文件: $log_file ($log_size 字节, $log_lines 行)"
    else
        echo "  日志文件: 不存在"
    fi
}

# 重启项目
restart_project() {
    local project_name="$1"
    
    if [[ -z "$project_name" ]]; then
        log_error "请指定项目名称"
        return 1
    fi
    
    log_info "重启项目: $project_name"
    
    # 先移除，再添加
    remove_project "$project_name"
    sleep 2
    project_setup "$project_name"
}

add_all_projects() {
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
}

project_setup() {
    local simple_register_script="/app/scripts/simple_register.sh"
    local project_name="$1"

    if [[ -f "$simple_register_script" ]]; then
        log_debug "使用简化注册脚本处理cron项目: $project_name"
        chmod +x "$simple_register_script"
                
        # 在子shell中调用simple_register.sh注册项目，并捕获所有输出
        log_debug "开始调用simple_register.sh..."
        local register_result=0
                
        # 使用更安全的调用方式
        bash "$simple_register_script" "$project_name"
        register_result=$?
                
        log_debug "simple_register.sh返回码: $register_result"
                
        if [[ $register_result -eq 0 ]]; then
            log_info "项目 $project_name 注册成功"
            log_debug "simple_register.sh执行成功"
            log_debug "execute_project_setup函数处理完成: $project_name"
            return 0
        else
            log_error "项目 $project_name 注册失败 (返回码: $register_result)"
            log_debug "simple_register.sh执行失败"
            log_debug "execute_project_setup函数处理完成: $project_name"
            return 1
        fi
    else
        log_error "简化注册脚本不存在: $simple_register_script"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
自动脚本执行管理器

用法: $0 <command> [options]

命令:
  update/-u                  扫描并注册所有项目
  add/-a <project_name>      添加单个项目
  remove/-rm <project_name>  移除项目
  list/-l                    列出所有项目
  status/-s <project_name>   查看项目状态
  restart/-rs <project_name> 重启项目
  help/-h                    显示帮助信息

示例:
  $0 update
  $0 add task1
  $0 status task1
  $0 restart task1
  $0 list

环境变量:
  DEBUG=true              启用调试输出

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
        "update"|"-u")
            add_all_projects
            ;;
        "remove"|"-rm")
            local project_name="$1"
            if [[ -z "$project_name" ]]; then
                log_error "请指定项目名称"
                return 1
            fi
            remove_project "$project_name"
            ;;
        "add"|"-a")
            local project_name="$1"
            if [[ -z "$project_name" ]]; then
                log_error "请指定项目名称"
                return 1
            fi
            project_setup "$project_name"
            ;;
        "list"|"-l")
            list_projects
            ;;
        "status"|"-s")
            local project_name="$1"
            if [[ -z "$project_name" ]]; then
                log_error "请指定项目名称"
                return 1
            fi
            project_status "$project_name"
            ;;
        "restart"|"-rs")
            local project_name="$1"
            if [[ -z "$project_name" ]]; then
                log_error "请指定项目名称"
                return 1
            fi
            restart_project "$project_name"
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