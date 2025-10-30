#!/bin/bash

# 更新系统并安装必要工具
sudo apt update && sudo apt install -y wget curl openssl

# 进入临时目录
cd /tmp

# 自动获取最新gost版本号 (使用兼容性更强的命令)
latest_version=$(curl -s "https://api.github.com/repos/go-gost/gost/releases/latest" | grep '"tag_name"' | awk -F '"' '{print $4}' | sed 's/v//')
wget "https://github.com/go-gost/gost/releases/download/v${latest_version}/gost_${latest_version}_linux_amd64.tar.gz"

# 解压并安装
tar -zxvf "gost_${latest_version}_linux_amd64.tar.gz"
sudo mv "gost_${latest_version}_linux_amd64/gost" /usr/local/bin/

# 创建证书存放目录
sudo mkdir -p /etc/gost

# 生成自签名SSL证书
sudo openssl req -x509 -nodes -newkey rsa:2048 \
-keyout /etc/gost/key.pem \
-out /etc/gost/cert.pem -days 3650 \
-subj "/C=US/ST=CA/L=Los Angeles/O=Global/OU=IT/CN=metaleks.proxy"

# 创建systemd服务文件，实现开机自启 (已填入您的信息)
sudo tee /etc/systemd/system/gost.service > /dev/null <<-'EOF'
[Unit]
Description=Gost Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -L "ss+tls://metaleks:20100604@:8443?cert=/etc/gost/cert.pem&key=/etc/gost/key.pem"
Restart=always
User=root
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 重新加载配置并启动gost服务
sudo systemctl daemon-reload
sudo systemctl enable gost
sudo systemctl start gost

# 开放防火墙端口 (兼容Ubuntu的ufw和CentOS的firewalld)
if command -v ufw &> /dev/null; then
    sudo ufw allow 8443/tcp
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --zone=public --add-port=8443/tcp --permanent
    sudo firewall-cmd --reload
fi

# 打印最终的运行状态和成功信息
echo "--------------------------------------------------"
sudo systemctl status gost --no-pager
echo ""
echo -e "\033[32mSocks5 over TLS 代理服务已成功部署并启动！\033[0m"
echo "请在您的指纹浏览器中按以下信息配置。"
echo "--------------------------------------------------"
