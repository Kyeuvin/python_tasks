#!/bin/bash

# =================================
# 文件权限设置脚本
# 功能：为项目文件和脚本设置正确的权限
# =================================

echo "设置文件权限..."

# 设置脚本目录权限
chmod 777 /app/scripts/*.sh 2>/dev/null || true

# 设置项目setup.sh权限
for task_dir in /app/*; do
    if [[ -d "$task_dir" && -f "$task_dir/setup.sh" ]]; then
        chmod 777 "$task_dir/setup.sh"
        echo "已设置 $task_dir/setup.sh 执行权限"
    fi
done

# 设置Python脚本权限
find /app -name "*.py" -type f -exec chmod 777 {} \; 2>/dev/null || true

# 设置日志目录权限
mkdir -p /app/logs/system /app/logs/projects
chmod 777 /app/logs /app/logs/system /app/logs/projects

echo "权限设置完成"