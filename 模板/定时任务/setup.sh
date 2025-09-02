#!/bin/bash

# =================================
# 项目配置脚本: 
# 描述: 
# 项目类型: 定时任务
# =================================

# 基本项目信息
PROJECT_NAME="$(basename "$(pwd)")"
PROJECT_TYPE="cron"

# 定时任务配置
CRON_SCHEDULE="* * * * *" # 每分钟执行
CRON_COMMAND="cd /app/$PROJECT_NAME && python main.py"

# 依赖检查函数 (可选)
check_dependencies() {
    echo "检查项目依赖..."
    
    # 示例：检查主程序文件
    if [[ ! -f "main.py" ]] && [[ ! -f "service.py" ]] && [[ ! -f "app.py" ]]; then
        echo "警告：未找到主程序文件 (main.py, service.py, app.py)"
    fi
    
    # 示例：检查Python包依赖
    # python3 -c "import requests" 2>/dev/null || {
    #     echo "错误：缺少 requests 包"
    #     return 1
    # }
    
    echo "依赖检查通过"
    return 0
}

# 项目初始化函数 (可选)
initialize() {
    echo "初始化项目: $PROJECT_NAME"
    
    # 示例：创建必要目录
    # mkdir -p data logs temp 2>/dev/null || true
    
    # 示例：设置权限
    chmod 755 . 2>/dev/null || true
    
    echo "初始化完成"
    return 0
}

# 项目清理函数 (可选)
cleanup() {
    echo "清理项目: $PROJECT_NAME"
    
    # 示例：清理临时文件
    rm -rf temp/* 2>/dev/null || true
    
    echo "清理完成"
    return 0
}
