#!/bin/bash

# =================================
# 项目配置脚本: 
# 描述: 
# 项目类型: 后台服务
# =================================

# 基本项目信息
PROJECT_NAME="$(basename "$(pwd)")"
PROJECT_TYPE="service"

# 后台服务配置
SERVICE_COMMAND="cd /app/$PROJECT_NAME && python3 main.py"
SERVICE_RESTART_POLICY="always"

# 依赖检查函数(可选)
check_dependencies() {
    echo "检查项目依赖..."
    
    # 检查主程序文件
    if [[ ! -f "main.py" ]]; then
        echo "错误：找不到 main.py 文件"
        return 1
    fi
    
    # 检查Python环境
    if ! command -v python3 &> /dev/null; then
        echo "错误：Python3 未安装"
        return 1
    fi
    
    echo "依赖检查通过"
    return 0
}

# 项目初始化函数(可选)
initialize() {
    echo "初始化项目..."
    
    # 创建必要目录
    # mkdir -p data logs temp 2>/dev/null || true
    
    # 设置权限
    chmod 755 . 2>/dev/null || true
    chmod +x *.py 2>/dev/null || true
    
    echo "task4初始化完成"
    return 0
}

# 项目清理函数(可选)
cleanup() {
    echo "清理task4项目..."
    
    # 停止相关进程
    pkill -f "task4" 2>/dev/null || true
    
    # 清理临时文件
    rm -rf temp/* 2>/dev/null || true
    
    echo "task4清理完成"
    return 0
}