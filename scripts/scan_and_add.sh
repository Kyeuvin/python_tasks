#!/bin/bash

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

# create_directories() {
#     mkdir -p "$SYSTEM_LOG_DIR" "$PROJECTS_LOG_DIR"
#     touch "$REGISTRATION_LOG" "$SERVICES_CONF"
#     chmod 755 "$SYSTEM_LOG_DIR" "$PROJECTS_LOG_DIR"
#     chmod 644 "$REGISTRATION_LOG" "$SERVICES_CONF"
# }

# # 验证setup.sh脚本格式
# validate_setup_script() {
#     local project_name="$1"
#     local setup_file="$PROJECTS_DIR/$project_name/setup.sh"
    
#     log_debug "验证项目 $project_name 的setup.sh脚本格式"
    
#     # 检查文件是否可执行
#     if [[ ! -x "$setup_file" ]]; then
#         log_warn "setup.sh文件不可执行，尝试添加执行权限"
#         chmod +x "$setup_file"
#     fi
    
#     # 检查脚本语法
#     if ! bash -n "$setup_file" 2>/dev/null; then
#         log_error "项目 $project_name 的setup.sh语法错误"
#         return 1
#     fi
    
#     return 0
# }

# # 注册后台服务
# register_background_service() {
#     local project_name="$1"
#     local command="$2"
#     local restart_policy="${3:-always}"
#     local log_file="$PROJECTS_LOG_DIR/${project_name}.log"
#     local pid_file="$PROJECTS_LOG_DIR/${project_name}.pid"
    
#     log_info "注册后台服务: $project_name"
#     log_debug "  命令: $command"
#     log_debug "  重启策略: $restart_policy"
#     log_debug "  日志: $log_file"
#     log_debug "  PID文件: $pid_file"
    
#     # 确保日志文件存在
#     touch "$log_file"
#     chmod 666 "$log_file"
    
#     # 检查是否已存在运行中的服务
#     if [[ -f "$pid_file" ]]; then
#         local old_pid=$(cat "$pid_file" 2>/dev/null)
#         if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
#             log_warn "项目 $project_name 的后台服务已运行 (PID: $old_pid)，跳过启动"
#             return 0
#         fi
#     fi
    
#     # 启动后台服务
#     nohup bash -c "$command" >> "$log_file" 2>&1 &
#     local new_pid=$!
#     echo "$new_pid" > "$pid_file"
    
#     # 添加到监控列表
#     echo "$project_name:$restart_policy:$command" >> "$SERVICES_CONF"
    
#     # 记录注册信息
#     echo "$(date): SERVICE注册 $project_name PID:$new_pid" >> "$REGISTRATION_LOG"
#     log_info "后台服务注册成功: $project_name (PID: $new_pid)"
    
#     return 0
# }

# 项目处理
execute_project_setup() {
    # local project_name="$1"
    # local project_dir="$PROJECTS_DIR/$project_name"
    # local setup_file="$project_dir/setup.sh"
    
    # log_info "执行项目配置: $project_name"
    
    # # 检查项目目录和setup.sh是否存在
    # if [[ ! -d "$project_dir" ]]; then
    #     log_error "项目目录不存在: $project_dir"
    #     return 1
    # fi
    
    # if [[ ! -f "$setup_file" ]]; then
    #     log_error "项目 $project_name 没有setup.sh文件"
    #     return 1
    # fi
    
    # # 验证setup.sh脚本
    # if ! validate_setup_script "$project_name"; then
    #     log_error "项目 $project_name 的setup.sh验证失败"
    #     return 1
    # fi
    
    # # 读取项目配置
    # local project_config
    # project_config=$(
    #     cd "$project_dir"
    #     source ./setup.sh >/dev/null 2>&1
    #     echo "PROJECT_NAME=${PROJECT_NAME:-$project_name}"
    #     echo "PROJECT_TYPE=${PROJECT_TYPE:-cron}"
    #     echo "CRON_SCHEDULE=${CRON_SCHEDULE:-}"
    #     echo "CRON_COMMAND=${CRON_COMMAND:-}"
    #     echo "SERVICE_COMMAND=${SERVICE_COMMAND:-}"
    #     echo "SERVICE_RESTART_POLICY=${SERVICE_RESTART_POLICY:-always}"
    # )
    
    # # 安全解析配置
    # local PROJECT_NAME PROJECT_TYPE CRON_SCHEDULE CRON_COMMAND SERVICE_COMMAND SERVICE_RESTART_POLICY
    # while IFS='=' read -r key value; do
    #     case "$key" in
    #         "PROJECT_NAME") PROJECT_NAME="$value" ;;
    #         "PROJECT_TYPE") PROJECT_TYPE="$value" ;;
    #         "CRON_SCHEDULE") CRON_SCHEDULE="$value" ;;
    #         "CRON_COMMAND") CRON_COMMAND="$value" ;;
    #         "SERVICE_COMMAND") SERVICE_COMMAND="$value" ;;
    #         "SERVICE_RESTART_POLICY") SERVICE_RESTART_POLICY="$value" ;;
    #     esac
    # done <<< "$project_config"
    
    # log_debug "项目类型: $PROJECT_TYPE"

    local simple_register_script="/app/scripts/simple_register.sh"

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

    # # 根据项目类型选择处理方式
    # case "$PROJECT_TYPE" in
    #     "cron")
    #         if [[ -f "$simple_register_script" ]]; then
    #             log_debug "使用简化注册脚本处理cron项目: $project_name"
    #             chmod +x "$simple_register_script"
                
    #             # 在子shell中调用simple_register.sh注册项目，并捕获所有输出
    #             log_debug "开始调用simple_register.sh..."
    #             local register_result=0
                
    #             # 使用更安全的调用方式
    #             bash "$simple_register_script" "$project_name"
    #             register_result=$?
                
    #             log_debug "simple_register.sh返回码: $register_result"
                
    #             if [[ $register_result -eq 0 ]]; then
    #                 log_info "项目 $project_name 注册成功"
    #                 log_debug "simple_register.sh执行成功"
    #                 log_debug "execute_project_setup函数处理完成: $project_name"
    #                 return 0
    #             else
    #                 log_error "项目 $project_name 注册失败 (返回码: $register_result)"
    #                 log_debug "simple_register.sh执行失败"
    #                 log_debug "execute_project_setup函数处理完成: $project_name"
    #                 return 1
    #             fi
    #         else
    #             log_error "简化注册脚本不存在: $simple_register_script"
    #             return 1
    #         fi
    #         ;;
    #     "service")
    #         if [[ -f "$simple_register_script" ]]; then
    #             log_debug "使用简化注册脚本处理service项目: $project_name"
    #             chmod +x "$simple_register_script"
                
    #             # 在子shell中调用simple_register.sh注册项目，并捕获所有输出
    #             log_debug "开始调用simple_register.sh..."
    #             local register_result=0
                
    #             # 使用更安全的调用方式
    #             bash "$simple_register_script" "$project_name"
    #             register_result=$?
                
    #             log_debug "simple_register.sh返回码: $register_result"
                
    #             if [[ $register_result -eq 0 ]]; then
    #                 log_info "项目 $project_name 注册成功"
    #                 log_debug "simple_register.sh执行成功"
    #                 log_debug "execute_project_setup函数处理完成: $project_name (service类型成功)"
    #                 return 0
    #             else
    #                 log_error "项目 $project_name 注册失败 (返回码: $register_result)"
    #                 log_debug "simple_register.sh执行失败"
    #                 log_debug "execute_project_setup函数处理完成: $project_name (service类型失败)"
    #                 return 1
    #             fi
    #         else
    #             log_error "简化注册脚本不存在: $simple_register_script"
    #             return 1
    #         fi
    #         ;;
    #     *)
    #         log_error "不支持的项目类型: $PROJECT_TYPE"
    #         return 1
    #         ;;
    # esac
    
    log_debug "execute_project_setup函数处理完成: $project_name"
}

# 使用相同的扫描逻辑
PROJECTS_DIR="/app"
    
log_info "执行项目扫描和注册..."
scan_projects() {
    echo "开始扫描项目目录: $PROJECTS_DIR" >&2
    local discovered_projects=()
    
    for project_dir in "$PROJECTS_DIR"/*/; do
        if [[ -d "$project_dir" ]]; then
            local project_name=$(basename "$project_dir")
            local setup_file="$project_dir/setup.sh"
            
            # 跳过系统目录
            if [[ "$project_name" =~ ^(logs|scripts|data|backup)$ ]]; then
                echo "跳过系统目录: $project_name" >&2
                continue
            fi
            
            if [[ -f "$setup_file" ]]; then
                echo "发现项目: $project_name (setup.sh存在)" >&2
                discovered_projects+=("$project_name")
            fi
        fi
    done
    
    log_info "共发现 ${#discovered_projects[@]} 个项目: ${discovered_projects[*]}" >&2
    echo "${discovered_projects[@]}"
}


# 主逻辑
projects=($(scan_projects))
total_count=${#projects[@]}

echo "发现 $total_count 个项目: ${projects[*]}"

echo "开始循环处理..."
for project in "${projects[@]}"; do
    echo "========================================="
    echo "处理项目: $project"
    
    if execute_project_setup "$project"; then
        echo "项目 $project 处理成功"
    else
        echo "项目 $project 配置失败"
    fi
    
    echo "项目 $project 处理完成，继续下一个..."
    echo ""
done

echo "========================================="
echo "循环处理完成"
echo "扫描完成: 项目配置成功"