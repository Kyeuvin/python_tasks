# Python2Docker
本项目用于创建一个可以方便管理多个Python脚本/项目的容器。

## 使用方法
### 容器的操作
在终端中的项目根目录下执行以下指令创建容器并启动：
``` 
docker build --non-cache   # 创建容器
docker compose up -d       # 启动容器
```
运行成功后，容器就创建成功了。可以输入以下指令进入容器：
```
docker exec -it python_tasks /bin/bash
```
如果需要关闭/重启容器，请输入以下指令：
```
docker compose down        # 关闭容器
docker compose up -d       # 重启容器
```
---
### Python脚本/程序添加并启动
①容器创建之后，进入容器：
```
docker exec -it python_tasks /bin/bash
```
②将Python脚本/程序(带目录结构)复制到PYTHON_TASKS目录下，并保证
1. 脚本/程序主入口的文件名为main.py
2. 脚本/程序依赖的包已安装
3. 脚本/程序主入口文件(main.py)在你的项目根目录下

③接下来添加启动脚本：根据你的项目类型（定时项目/后台项目），从模板文件夹复制setup.sh文件到你的项目根目录下（可根据你的需求自行修改setup.sh文件）。

④复制完成后，输入以下指令（你的项目名称就是你的项目根目录名称）：
```
cd /app/scripts
./project_manager.sh add <你的项目名称>
```
或
```
cd /app/scripts
./project_manager.sh update
```
如果你看到输出：
```
[INFO] 注册项目: <你的项目名称>
[INFO] 读取项目配置...
[INFO] 项目配置:
  名称: <你的项目名称>
  类型: <你的项目类型>
  调度: * * * * *
  命令: cd /app/<你的项目名称> && python3 main.py
[INFO] 正在添加新的crontab配置...
[INFO] crontab操作完成
[INFO] 验证crontab注册结果...
[INFO] 定时任务注册成功
[INFO] register_single_project函数完成: <你的项目名称>
[INFO] 2025-09-02 11:43:05 项目 <你的项目名称> 注册成功
```
说明项目注册成功了，你可以在`/app/logs/projects/`目录下查看项目日志。

---
### 其他项目操作
可通过
```
cd /app/scripts
./project_manager.sh help
```
获取更多帮助信息。