# 使用Python 3.12 slim版本作为基础镜像
FROM python:3.12-slim-bullseye

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple \
    PATH="/usr/local/bin:$PATH" 
    
#切换国内apt源
RUN mv /etc/apt/sources.list /etc/apt/sources.list.bak && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free" > /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free" >> /etc/apt/sources.list

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    cron \
    tzdata \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 创建应用目录
WORKDIR /app

# 复制requirements.txt并安装Python依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


# 创建日志和数据目录
RUN mkdir -p /app/logs /app/data

# 设置脚本执行权限
RUN chmod +x /app/scripts/*.sh

# 创建python符号链接（确保python命令可用）
RUN ln -sf /usr/local/bin/python3 /usr/local/bin/python

# 复制并设置入口脚本权限
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# 创建cron日志文件
RUN touch /var/log/cron.log

# 暴露端口（用于健康检查）
EXPOSE 8080

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]