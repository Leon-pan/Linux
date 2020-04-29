#server
yum install -y krb5-server openldap-clients krb5-workstation

#client
yum install krb5-workstation krb5-libs

#建库
kdb5_util create -s -r HADOOP.COM

#删库
kdb5_util destroy

#建用户
kadmin.local -q "addprinc root/admin"


#/etc/krb5.conf
# Configuration snippets may be placed in this directory as well
includedir /etc/krb5.conf.d/
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log
[libdefaults]
 default_realm = HADOOP.COM
 #让Kerberos在TCP之前尝试UDP，以获得更快的传输速度
 udp_preference_limit = 1
 ticket_lifetime = 24h
 renew_lifetime = 7d
 dns_lookup_kdc = false
 dns_lookup_realm = false
 forwardable = true
 default_tgs_enctypes = rc4-hmac
 default_tkt_enctypes = rc4-hmac
 permitted_enctypes = rc4-hmac
 kdc_timeout = 3000
 #default_ccache_name = KEYRING:persistent:%{uid}
[realms]
 HADOOP.COM = {
  kdc = IP
  admin_server = IP
 }
[domain_realm]
 .hadoop.com = HADOOP.COM
 hadoop.com = HADOOP.COM


#/var/kerberos/krb5kdc/kdc.conf
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 HADOOP.COM = {
  #master_key_type = aes256-cts
  max_renewable_life = 7d 0h 0m 0s
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
  supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal camellia256-cts:normal camellia128-cts:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
  default_principal_flags = +renewable
 }


#/var/kerberos/krb5kdc/kadm5.acl
*/admin@HADOOP.COM	*


#Kerberos认证
kadmin.local

listprincs

kadmin.local -q "addprinc HTTP"

kinit hdfs
kinit -kt /path user
#导出keytab文件并不修改密码
xst -k admin.keytab -norandkey admin/admin@HADOOP.COM
ktadd -kt admin.keytab admin/admin@HADOOP.COM

klist

#Hue
Kerberos Ticket Renewer服务启动报错
kadmin.local:  modprinc -maxrenewlife 90day krbtgt/HADOOP.COM@HADOOP.COM

kadmin.local:  modprinc -maxrenewlife 90day +allow_renewable hue/namenode01.hadoop@HADOOP.COM


#新增admin用户，并加入hadoop组(hadoop组需已存在)
useradd -g hadoop admin


#Hive
beeline
!connect jdbc:hive2://namenode01.hadoop:10000/;principal=hive/namenode01.hadoop@60HADOOP.COM


配置更改项：
YARN
banned.users
allowed.system.users
min.user.id

HBase
hbase.security.authentication
hbase.thrift.security.qop
hbase.security.authorization
#HBase开启doAs模拟，意味着用户可以通过Hue向HBase发送命令，而不会失去他们自己的凭据（而不是使用'hue'用户）
#启用 HBase Thrift 代理用户
hbase.thrift.support.proxyuser
#启用 HBase Thrift Http 服务器
hbase.regionserver.thrift.http
#hbase.rest.authentication.type




Firefox浏览器
访问about:config 页面调整以下参数：
1.修改hosts
2. network.negotiate-auth.trusted-uris 允许使用gssapi链接验证的地址
3. network.auth.use-sspi 关闭sspi验证协议


https://www.ibm.com/support/knowledgecenter/zh/SSAW57_8.5.5/com.ibm.websphere.nd.multiplatform.doc/ae/tsec_SPNEGO_config_web.html