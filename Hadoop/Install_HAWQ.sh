##基于HDP的HAWQ集群安装
#修改系统内核参数
vi /etc/sysctl.conf

kernel.shmmax= 1000000000
kernel.shmmni= 4096
kernel.shmall= 4000000000
kernel.sem= 250 512000 100 2048
kernel.sysrq= 1
kernel.core_uses_pid= 1
kernel.msgmnb= 65536
kernel.msgmax= 65536
kernel.msgmni= 2048
net.ipv4.tcp_syncookies= 0
net.ipv4.ip_forward= 0
net.ipv4.conf.default.accept_source_route= 0
net.ipv4.tcp_tw_recycle= 1
net.ipv4.tcp_max_syn_backlog= 200000
net.ipv4.conf.all.arp_filter= 1
net.ipv4.ip_local_port_range= 1281 65535
net.core.netdev_max_backlog= 200000
vm.overcommit_memory= 2
fs.nr_open= 3000000
kernel.threads-max= 798720
kernel.pid_max= 798720
#increase network
net.core.rmem_max=2097152
net.core.wmem_max=2097152

#立即生效
sysctl -p


#修改系统限制
vi /etc/security/limits.conf

* soft nofile 2900000
* hard nofile 2900000
* soft nproc 131072
* hard nproc 131072


#创建HAWQ用户，并新建相关目录
useradd --home=/opt/gpadmin/ --no-create-home --comment "HAWQ admin" gpadmin 
echo gpadmin | passwd --stdin gpadmin 
mkdir -p /opt/gpadmin/.ssh
chown -R gpadmin:gpadmin /opt/gpadmin
#namenode节点，建议在所有节点上创建
mkdir -p /opt/gpadmin/hawq-data-directory/masterdd
#datanode节点，建议在所有节点上创建
mkdir -p /opt/gpadmin/hawq-data-directory/segmentdd
chown -R gpadmin:gpadmin /opt/gpadmin


echo 'gpadmin ALL=(ALL) NOPASSWD:ALL'  >> /etc/sudoers


#依赖安装
yum install epel-release
yum install man passwd sudo tar which git mlocate links make bzip2 net-tools \
  autoconf automake libtool m4 gcc gcc-c++ gdb bison flex gperf indent \
  libuuid-devel krb5-devel libgsasl-devel expat-devel libxml2-devel \
  perl-ExtUtils-Embed pam-devel python-devel libcurl-devel snappy-devel \
  thrift-devel libyaml-devel libevent-devel bzip2-devel openssl-devel \
  openldap-devel protobuf-devel readline-devel net-snmp-devel apr-devel \
  libesmtp-devel python-pip json-c-devel \
  lcov cmake3 \
  openssh-clients openssh-server perl-JSON perl-Env


#解压安装hawq主服务
tar -zxvf apache-hawq-rpm-2.4.0.0.tar.gz
cd hawq_rpm_packages/
rpm -ivh  apache-hawq-2.4.0.0-el7.x86_64.rpm


#在HDFS上新建目录，并赋权
hdfs dfs -mkdir /hawq_default
 
hdfs dfs -chown gpadmin:gpadmin /hawq_default


#切换至gpadmin用户，开始初始化集群
su - gpadmin
 
cd /usr/local/apache-hawq/etc/

#修改相关节点地址 
vi hawq-site.xml

cd /usr/local/apache-hawq/
 
source greenplum_path.sh 
 
cd ./bin

#需先配置gpadmin用户免密登录
./hawq ssh-exkeys -h 10.1.70.211 -h 10.1.70.210

#初始化集群
./hawq init cluster

#启动停止
./hawq start cluster
./hawq stop cluster

#修改.bash_profile文件
vi ~/.bash_profile
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/bin:/usr/local/apache-hawq/bin

export PATH
HAWQ_HOME=/opt/gpadmin
source /usr/local/apache-hawq/greenplum_path.sh
PXF_HOME=/opt/gpadmin/pxf

export HAWQ_HOME
export PXF_HOME


#修改postgresql可访问IP
vi $HAWQ_HOME/hawq-data-directory/masterdd/pg_hba.conf
host  all     gpadmin    0.0.0.0/0       trust

#查看一下效果
psql -U gpadmin -d postgres
\l


##HAWQ插件PXF安装
# 克隆
git clone https://git-wip-us.apache.org/repos/asf/hawq.git rel/v2.4.0.0

# 编译安装pxf
cd hawq/pxf

# 安装
export HAWQ_HOME=/opt/gpadmin
export PXF_HOME=$GPHOME/pxf
make install

#配置pxf
You will see the PXF configuration files in $PXF_HOME/conf

Update the following files based on your environment and hadoop directly layout.

##pxf-env.sh
#Set LD_LIBRARY_PATH to ${HADOOP_HOME}/lib/native
#Set PXF_LOGDIR to ${PXF_HOME}/logs
#Set PXF_RUNDIR to ${PXF_HOME}
#Set PXF_USER to your username

##pxf-log4j.properties
#Set log4j.appender.ROLLINGFILE.File to the expanded path of $PXF_HOME/logs/pxf-service.log. (Don't use the environment variable in this file)

##pxf-private.classpath(可以不改，初始化的时候模板会覆盖该文件)
#Update the library and configuration paths of hadoop,hive,pxf, etc. Use only absolute paths without referring to environment variables


#初始化pxf
# Deploy PXF
$PXF_HOME/bin/pxf init
# If you get an error "WARNING: instance already exists in ..." make sure you clean up pxf-service directory under $PXF_HOME/bin/pxf and rerun init
  
# Create PXF Log Dir
mkdir $PXF_HOME/logs
  
# Start PXF
$PXF_HOME/bin/pxf start
  
# Check Status
$PXF_HOME/bin/pxf status
# You can also check if the service is running by using the following request to check API version
curl "localhost:51200/pxf/ProtocolVersion"
  
# To stop PXF $PXF_HOME/bin/pxf stop


附：
https://www.longger.net/article/7159.html
https://cwiki.apache.org/confluence/display/HAWQ/PXF+Build+and+Install