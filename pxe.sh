Install_PXE() {
	mkdir /root/yum_bak >&/dev/null
	mv -f /etc/yum.repos.d/* /root/yum_bak
	cat > /etc/yum.repos.d/pxe.repo <<- 'EOF'
		[pxe]
		name=pxe
		baseurl=file:///root/pxe
		enabled=1
		gpgcheck=0
	EOF
	yum install -y dhcp
	cat > /etc/dhcp/dhcpd.conf <<- 'EOF'
		  	subnet 10.147.110.0 netmask 255.255.255.0 {
	        range 10.147.110.100 10.147.110.200;
	        option subnet-mask 255.255.255.0;
	        default-lease-time 21600;
	        max-lease-time 43200;
	        next-server 10.147.110.11;
	        filename "/pxelinux.0";
	}
	EOF
	systemctl start dhcpd
	netstat -tunlp | grep dhcp
	yum install -y tftp-server
	sed -i '/\<disable/c\\tdisable\t\t\t= no' /etc/xinetd.d/tftp
	systemctl start tftp
	netstat -tunlp | grep 69
	yum install -y httpd
	systemctl start httpd
	#将CentOS解压后的镜像上传到/var/www/html
	\cp -f /root/yum_bak/* /etc/yum.repos.d/
}