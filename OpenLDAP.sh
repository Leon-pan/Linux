#yum安装
yum -y install openldap-clients openldap-devel openldap-servers migrationtools sssd authconfig nss-pam-ldapd

#复制模板
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
chown -R ldap:ldap /var/lib/ldap/

#启动
systemctl start slapd

#设置OpenLDAP的管理员密码
slappasswd -s [password]
{SSHA}7H3xhvmLsIb88RdHEmdTTJDjvZr6vzD8

#编辑配置文件1
vi /etc/openldap/chrootpw.ldif
# specify the password generated above for "olcRootPW" section
dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcRootPW
olcRootPW: {SSHA}7H3xhvmLsIb88RdHEmdTTJDjvZr6vzD8

#编辑配置文件2
vi /etc/openldap/chdomain.ldif
#
# Backend database definitions
#

# replace to your own domain name for "dc=***,dc=***" section
# specify the password generated above for "olcRootPW" section
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth"
  read by dn.base="cn=Manager,dc=test,dc=com" read by * none

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=test,dc=com

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=Manager,dc=test,dc=com

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcRootPW
olcRootPW: {SSHA}7H3xhvmLsIb88RdHEmdTTJDjvZr6vzD8

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by
  dn="cn=Manager,dc=test,dc=com" write by anonymous auth by self write by * none
olcAccess: {1}to dn.base="" by * read
olcAccess: {2}to * by dn="cn=Manager,dc=test,dc=com" write by * read

#编辑配置文件3
vi /etc/openldap/basedomain.ldif
# replace to your own domain name for "dc=***,dc=***" section
dn: dc=test,dc=com
objectClass: top
objectClass: dcObject
objectclass: organization
o: Server Com
dc: test

dn: cn=Manager,dc=test,dc=com
objectClass: organizationalRole
cn: Manager
description: Directory Manager

dn: ou=People,dc=test,dc=com
objectClass: organizationalUnit
ou: People

dn: ou=Group,dc=test,dc=com
objectClass: organizationalUnit
ou: Group

#导入配置
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/chrootpw.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/openldap/chdomain.ldif
ldapadd -x -D cn=Manager,dc=test,dc=com -W -f /etc/openldap/basedomain.ldif

#导入一些基本的 Schema
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif