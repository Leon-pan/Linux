#!/bin/bash

#备份
cp -r /etc/ssh{,.old_$(date '+%F')}
cp /etc/pam.d/sshd{,.old_$(date '+%F')}
#解压
tar -zvxf openssh-7.9p1.tar.gz
#yum安装依赖
yum install gcc zlib-devel openssl-devel pam-devel -y
#配置
cd openssh-7.9p1
./configure --prefix=/usr/ --sysconfdir=/etc/ssh/ --with-md5-passwords --with-pam mandir=/usr/share/man/
#编译
make
#卸载旧openssh
rpm -qa | grep openssh | xargs rpm -e --nodeps
#配置
cp contrib/redhat/sshd.init /etc/init.d/sshd
chmod 755 /etc/init.d/sshd
chkconfig --add sshd
chkconfig sshd on
cp /etc/pam.d/sshd{.old_$(date '+%F'),}
chmod 600 /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ed25519_key
#安装
make install
sed -i '/^#UsePAM/c\UsePAM yes' /etc/ssh/sshd_config
#PermitRootLogin默认禁止root远程登录
sed -i '/^#PermitRootLogin/c\PermitRootLogin yes' /etc/ssh/sshd_config
#重启：
service sshd restart
