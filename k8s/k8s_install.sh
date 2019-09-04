#https://blog.rj-bai.com/post/160.html
关闭 swap&selinux&firewall


#安装docker，k8s官方建议安装docker18.06.2版本
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum -y install docker-ce-18.06.2.ce-3.el7
systemctl enable docker.service
systemctl start docker.service


#安装完docker后，k8s官方建议修改存储驱动为overlay2
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

#重启docker
systemctl daemon-reload
systemctl restart docker


修改hosts


#全部服务器执行，将桥接的 IPv4 流量传递到 iptables
cat > /etc/sysctl.d/k8s.conf <<OEF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
OEF

sysctl --system


#加载 IPVS 模块，全部服务器执行
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF

chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4


#安装 kubelet/kubeadm/kubectl
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

#安装完后将重新编译后有十年有效期的kubeadm替换/usr/bin/下的kubeadm
yum install -y kubelet-1.15.3 kubeadm-1.15.3 kubectl-1.15.3 --disableexcludes=kubernetes
#yum -y install ipvsadm  ipset


#集群初始化
[root@k8s ~]# vi kubeadm.yaml 
apiServer:
  extraArgs:
    authorization-mode: Node,RBAC
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: gcr.azk8s.cn/google_containers
kind: ClusterConfiguration
kubernetesVersion: v1.15.3
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.1.0.0/16
  podSubnet: 10.244.0.0/16
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs


#设置开机自启，并初始化
systemctl enable kubelet.service
kubeadm init --config kubeadm.yaml

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#从节点加入集群
kubeadm join 10.1.70.88:6443 --token zgmtzc.i4tvwr7a0jh6zvum \
    --discovery-token-ca-cert-hash sha256:96a13e39ac446c55260249014161b5c846c55491e0c933f223f36676aff15d56

#加入集群的格式为
kubeadm join <master-ip>:<master-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>

#token
kubeadm token list

#sha256
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'


#coredns 处于 pending 状态，所以现在需要部署一下容器的网络，用 flannel
kubectl apply -f kube-flannel.yml


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


#检查kube-proxy 是否为IPVS 模式
kubectl logs -n kube-system kube-proxy-xxxx

I0903 06:47:33.569723       1 server_others.go:170] Using ipvs Proxier.


#Kubernetes Dashboard安装
kubectl apply -f kubernetes-dashboard.yaml

kubectl proxy

#访问URL
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/



#获取token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')

kubectl -n kube-system describe $(kubectl -n kube-system get secret -n kube-system -o name | grep namespace) | grep token

kubectl proxy --address='0.0.0.0'  --accept-hosts='^*$'

eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuLXdycWxnIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIwYWZhMTk4MS1hNWQ3LTRiZDItOGY3Ni1jOTZiYTA3MzFmYWUiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06YWRtaW4tdXNlciJ9.mfN7QOkZy6I4VJWGQNFPcDy7Wdv4N7EQzaOmyV-PLAVFTPNekfgJbUZu3ZBAa5VoH_OudXRKgT9ZnIlQwxSWJyENQyWrYt_2qcySF0xB8-TmxeNRyTkDIX44bocuTaqbVAkCyS1M3QOPga7DTBXEd9k65hRvmRbYMF5c8LDjoIlVlO51Pql8-vzLwR5Yo7PWKgQqr_gw6LHe6ciwJ7plVfsVDH7nM9LSAOeuvEvzcre0ERcunDh6ueGbBrC3vWOqRH6-Gl1mucsRC_e-WIqOYx78Q7nkB-48ynVtGfoy6cFdzryNIPvyRvYqO4y7_VO6O3uZo6rU3_o4jrSq0jFqfQ