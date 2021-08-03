#https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
#关闭防火墙、swap分区等
systemctl disable --now firewalld
setenforce 0
sed -i '/^SELINUX=/c\SELINUX=disabled' /etc/selinux/config
swapoff -a && sysctl -w vm.swappiness=0
sed -ri '/^[^#]*swap/s@^@#@' /etc/fstab
#NetworkManage可能会干扰Calico代理正确路由的能力,建议关闭
systemctl disable --now NetworkManager


#安装docker，k8s官方建议安装docker18.09版本或19.03版本
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
yum install -y docker-ce-19.03.*

## Create /etc/docker
mkdir /etc/docker

# Set up the Docker daemon
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "live-restore": true
}
EOF

# Restart Docker
systemctl daemon-reload
systemctl enable --now docker


#使用阿里云镜像的k8s源
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF


#系统调优
cat <<EOF >> /etc/sysctl.conf
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv4.neigh.default.gc_interval=60
net.ipv4.neigh.default.gc_stale_time=120

# 参考 https://github.com/prometheus/node_exporter#disabled-by-default
kernel.perf_event_paranoid=-1

#sysctls for k8s node config
net.ipv4.tcp_slow_start_after_idle=0
net.core.rmem_max=16777216
fs.inotify.max_user_watches=524288
kernel.softlockup_all_cpu_backtrace=1

kernel.softlockup_panic=0

kernel.watchdog_thresh=30
fs.file-max=2097152
fs.inotify.max_user_instances=8192
fs.inotify.max_queued_events=16384
vm.max_map_count=262144
fs.may_detach_mounts=1
net.core.netdev_max_backlog=16384
net.ipv4.tcp_wmem=4096 12582912 16777216
net.core.wmem_max=16777216
net.core.somaxconn=32768
net.ipv4.ip_forward=1
net.ipv4.tcp_max_syn_backlog=8096
net.ipv4.tcp_rmem=4096 12582912 16777216

net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

kernel.yama.ptrace_scope=0
vm.swappiness=0

# 可以控制core文件的文件名中是否添加pid作为扩展。
kernel.core_uses_pid=1

# Do not accept source routing
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0

# Promote secondary addresses when the primary address is removed
net.ipv4.conf.default.promote_secondaries=1
net.ipv4.conf.all.promote_secondaries=1

# Enable hard and soft link protection
fs.protected_hardlinks=1
fs.protected_symlinks=1

# 源路由验证
# see details in https://help.aliyun.com/knowledge_detail/39428.html
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce=2
net.ipv4.conf.all.arp_announce=2

# see details in https://help.aliyun.com/knowledge_detail/41334.html
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_synack_retries=2
kernel.sysrq=1
EOF

sysctl -p

#nofile
cat >> /etc/security/limits.conf <<EOF
* soft nofile 65535
* hard nofile 65536
EOF


#安装k8s组件，这里选用1.18版本
yum list kubeadm.x86_64 --showduplicates
yum install -y kubeadm-1.18.* kubelet-1.18.* kubectl-1.18.* #--disableexcludes=kubernetes禁掉除此外的其他仓库

systemctl enable --now kubelet


#CentOS 7可能遇到由于iptables被绕过而导致流量无法正确路由的问题
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward=1
EOF
sysctl --system


#加载 IPVS 模块，性能优于iptables
#安装ipvs客户端
yum install ipvsadm
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
#1.20需要开启br_netfilter
modprobe -- br_netfilter
modprobe -- bridge

#Linux内核4.19和更高版本中使用nf_conntrack代替nf_conntrack_ipv4
kernel_version=$(uname -r | cut -d- -f1)
if version_ge "${kernel_version}" 4.19; then
  modprobe -- nf_conntrack
else
  modprobe -- nf_conntrack_ipv4
fi
EOF

chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4


#ipvs优化
cat <<EOF >> /etc/sysctl.conf
#ipvs https://blog.csdn.net/bh1231/article/details/100947990
net.netfilter.nf_conntrack_max=1048576
net.nf_conntrack_max=1048576
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_probes=10
net.ipv4.tcp_keepalive_intvl=30
EOF


#集群配置文件
cat > init.yaml <<- 'EOF'
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: 7t2weq.bjbawausm0jaxury
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 1.2.3.4 #主节点IP
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: k8s-master01 #主节点hostname
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: LOAD_BALANCER_DNS:LOAD_BALANCER_PORT #主节点高可用
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers #使用阿里云镜像
kind: ClusterConfiguration
kubernetesVersion: v1.18.16 #版本号，同kubeadm版本
networking:
  dnsDomain: cluster.local
  podSubnet: 172.168.0.0/16 #pod网段
  serviceSubnet: 10.96.0.0/12 #svc网段
scheduler: {}
EOF

#使用kubeadm安装时在配置文件添加以下部分使用ipvs
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs


#提前下载镜像，节省初始化时间
kubeadm config images pull --config init.yaml


#初始化集群
kubeadm init --config init.yaml --upload-certs
#--image-repository registry.aliyuncs.com/google_containers


#配置环境变量，用于访问Kubernetes集群
cat <<EOF >> /root/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf
EOF
source /root/.bashrc


#Calico安装
#修改calico-etcd.yaml
sed -i 's#etcd_endpoints: "http://<ETCD_IP>:<ETCD_PORT>"#etcd_endpoints: "https://主节点1IP:2379,https://主节点1IP:2379"#g' calico-etcd-v3.16.8.yaml

ETCD_CA=`cat /etc/kubernetes/pki/etcd/ca.crt | base64 | tr -d '\n'`
ETCD_CERT=`cat /etc/kubernetes/pki/etcd/server.crt | base64 | tr -d '\n'`
ETCD_KEY=`cat /etc/kubernetes/pki/etcd/server.key | base64 | tr -d '\n'`
sed -i "s@# etcd-key: null@etcd-key: ${ETCD_KEY}@g; s@# etcd-cert: null@etcd-cert: ${ETCD_CERT}@g; s@# etcd-ca: null@etcd-ca: ${ETCD_CA}@g" calico-etcd-v3.16.8.yaml

sed -i 's#etcd_ca: ""#etcd_ca: "/calico-secrets/etcd-ca"#g; s#etcd_cert: ""#etcd_cert: "/calico-secrets/etcd-cert"#g; s#etcd_key: "" #etcd_key: "/calico-secrets/etcd-key" #g' calico-etcd-v3.16.8.yaml

POD_SUBNET=`cat /etc/kubernetes/manifests/kube-controller-manager.yaml | grep cluster-cidr= | awk -F= '{print $NF}'`

sed -i 's@# - name: CALICO_IPV4POOL_CIDR@- name: CALICO_IPV4POOL_CIDR@g; s@#   value: "192.168.0.0/16"@  value: '"${POD_SUBNET}"'@g' calico-etcd-v3.16.8.yaml

#创建calico
kubectl apply -f calico-etcd-v3.16.8.yaml


#安装Metrics Server
#将主节点的front-proxy-ca.crt复制到所有节点
scp /etc/kubernetes/pki/front-proxy-ca.crt 其他节点:/etc/kubernetes/pki/front-proxy-ca.crt
kubectl create -f metrics-server-v0.4.2.yml


#安装ingress
kubectl apply -f ingress-nginx-controller-v0.44.0.yml


#安装国产dashboard
https://www.kuboard.cn/install/install-dashboard.htm


#查看节点和容器状态
kubectl get node
kubectl get pod -A


#部署nginx测试
kubectl run nginx --replicas=3 --image=nginx:latest --port=80
kubectl expose deployment nginx --port=80 --type=NodePort --target-port=80 --name=nginx-service
kubectl get svc,pod -o wide


#测试coredns
[root@k8s ~]# kubectl run -it --image=busybox:1.28.4 --rm --restart=Never sh
/ # nslookup kubernetes


#开启ipvs
#修改ConfigMap的kube-system/kube-proxy中的config.conf，把 mode: "" 改为mode: “ipvs" 保存退出即可
kubectl edit cm kube-proxy -n kube-system

###删除之前的proxy pod
kubectl get pod -n kube-system |grep kube-proxy |awk '{system("kubectl delete pod "$1" -n kube-system")}'

#查看日志,如果有 `Using ipvs Proxier.` 说明kube-proxy的ipvs 开启成功!
kubectl logs -n kube-system kube-proxy-xxxx

I0903 06:47:33.569723       1 server_others.go:170] Using ipvs Proxier.