#/bin/bash
#获取dhcp配置文件
d2s() {
	network_name=$(ls /etc/sysconfig/network-scripts/ | grep ifcfg | grep -v lo)
	network_file=/etc/sysconfig/network-scripts/$network_name
	check_dhcp=$(grep BOOTPROTO $network_file | awk -F = '{print $2}')
	echo "网卡文件路径为$network_file"
	if [ -z $network_name ]; then
		echo "error"
		exit 1
	fi
	if [ $check_dhcp != dhcp ]; then
		echo "非动态地址，退出"
		exit 0
	else
		echo "当前为动态地址，开始执行脚本"
	fi
	ip=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}' | grep -v 0.1)
	if ! grep "IPADDR" $network_file > /dev/null 2>&1; then
		sed -i '/^BOOTPROTO=/c\BOOTPROTO=static' $network_file
        cat >> $network_file <<- EOF
			IPADDR=$ip
			PREFIX=22
			GATEWAY=172.16.27.254
			DNS1=114.114.114.114
			EOF
		echo "开始重启网卡..."
		systemctl restart network
		echo "网卡重启完毕..."
	else
		echo "请检查网卡配置"
	fi
}

d2s
