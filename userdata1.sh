#!/bin/bash
sudo yum -y install httpd
sudo systemctl httpd start  
sudo yum -y install firewalld
sudo systemctl firewalld start
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
echo "server1"