#安装Zabbix repository
rpm -Uvh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm
yum clean all


#安装Zabbix server, frontend, agent
yum -y install zabbix-server-mysql zabbix-web-mysql zabbix-agent


#建库，导库
mysql> create database zabbix character set utf8 collate utf8_bin;
mysql> grant all privileges on zabbix.* to zabbix@localhost identified by 'password';
mysql> quit;
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uzabbix -p zabbix


#修改配置文件
vi /etc/zabbix/zabbix_server.conf
DBPassword=password

vi /etc/httpd/conf.d/zabbix.conf
php_value date.timezone Asia/Shanghai


#启动
systemctl restart zabbix-server zabbix-agent httpd
systemctl enable zabbix-server zabbix-agent httpd


#agent端安装、配置
yum upgrade curl -y
rpm -Uvh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm
yum -y install zabbix-agent

vi /etc/zabbix/zabbix_agentd.conf
Server：用于指定允许哪台服务器拉取当前服务器的数据，当agent端工作于被动模式，则代表server端会主动拉取agent端数据，那么server端的IP必须与此参数的IP对应，此参数用于实现基于IP的访问控制，如果有多个IP ,可以使用逗号隔开。
ServerActive：此参数用于指定当agent端工作于主动模式时，将信息主动推送到哪台server上，当有多个IP时，可以用逗号隔开。
Hostname：此参数用于指定当前主机的主机名，server端通过此参数对应的主机名识别当前主机。客户端的名称，要和在网页中配置的名称一致

systemctl restart zabbix-agent
systemctl enable zabbix-agent


#zabbix界面乱码
在windows系统找一个中文字体上传到服务器/usr/share/fonts/dejavu/
mv SIMSUN.ttc SIMSUN.ttf
ln -s /usr/share/fonts/dejavu/SIMSUN.ttf /etc/alternatives/zabbix-web-font