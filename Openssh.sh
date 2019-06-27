#备份：
cp -r /etc/ssh{,.old_$(date '+%F')}
cp /etc/pam.d/sshd{,.old_$(date '+%F')}
#解压：
tar -zvxf openssh-7.9p1.tar.gz
#yum
yum install gcc zlib-devel openssl-devel pam-devel -y
#配置：
cd openssh-7.9p1
./configure --prefix=/usr/ --sysconfdir=/etc/ssh/ --with-md5-passwords --with-pam mandir=/usr/share/man/
#编译安装：
make
rpm  -qa | grep openssh | xargs rpm -e --nodeps
cp contrib/redhat/sshd.init /etc/init.d/sshd
chmod 755 /etc/init.d/sshd
chkconfig --add sshd
chkconfig sshd on
cp /etc/pam.d/sshd{.old_$(date '+%F'),}
chmod 600 /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ed25519_key
make install
#重启：
service sshd restart