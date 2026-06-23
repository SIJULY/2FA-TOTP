# 使用官方的 Nginx 镜像
FROM nginx:alpine

# 安装 tzdata 包
RUN apk add --no-cache tzdata

# 设置时区为北京时间
ENV TZ=Asia/Shanghai

# 将当前目录的内容复制到 Nginx 的 HTML 目录中
COPY . /usr/share/nginx/html

# 将 Nginx 配置文件复制到容器中
COPY default.conf /etc/nginx/conf.d/

# 启动 Nginx
CMD sed -i -e 's/$PORT/'"$PORT"'/g' /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'