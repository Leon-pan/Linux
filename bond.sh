#!/bin/bash
#创建一个名为bond0的链路接口
IP=10.147.111.11
GATE=10.147.111.254
MASK=24
ETH1=enp4s0f0
ETH2=enp4s0f1
#ETH3=eno3
#ETH4=eno4
modprobe bonding
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-bond0
DEVICE=bond0
TYPE=Bond
NAME=bond0
BONDING_MASTER=yes
BOOTPROTO=static
USERCTL=no
ONBOOT=yes
IPADDR=$IP
PREFIX=$MASK
GATEWAY=$GATE
BONDING_OPTS="mode=0 miimon=100"
EOF
#cat <<EOF> /etc/sysconfig/network-scripts/ifcfg-bond1
#DEVICE=bond1
#TYPE=Bond
#NAME=bond1
#BONDING_MASTER=yes
#USERCTL=no
#BOOTPROTO=none
#ONBOOT=yes
#BONDING_OPTS="mode=0 miimon=100"
#EOF
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$ETH1
TYPE=Ethernet
BOOTPROTO=none
DEVICE=$ETH1
ONBOOT=yes
MASTER=bond0
SLAVE=yes
EOF
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$ETH2
TYPE=Ethernet
BOOTPROTO=none
DEVICE=$ETH2
ONBOOT=yes
MASTER=bond0
SLAVE=yes
EOF
#cat <<EOF> /etc/sysconfig/network-scripts/ifcfg-$ETH3
#TYPE=Ethernet
#BOOTPROTO=none
#DEVICE=$ETH3
#ONBOOT=yes
#MASTER=bond1
#SLAVE=yes
#EOF
#cat <<EOF> /etc/sysconfig/network-scripts/ifcfg-$ETH4
#TYPE=Ethernet
#BOOTPROTO=none
#DEVICE=$ETH4
#ONBOOT=yes
#MASTER=bond1
#SLAVE=yes
#EOF
systemctl restart network
ping $GATE -c 10
#mode=0，表示load balancing (round-robin)为负载均衡方式，两块网卡都工作，但是与网卡相连的交换必须做特殊配置（ 这两个端口应该采取聚合方式），因为做bonding的这两块网卡是使用同一个MAC地址
#mode=6，表示load balancing (round-robin)为负载均衡方式，两块网卡都工作，但是该模式下无需配置交换机，因为做bonding的这两块网卡是使用不同的MAC地址
#mode=1，表示fault-tolerance (active-backup)提供冗余功能，工作方式是主备的工作方式，也就是说默认情况下只有一块网卡工作,另一块做备份
#reboot
#modprobe bonding
#lsmod | grep bonding
#cat /proc/net/bonding/bond0
#https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/7/html/networking_guide/
