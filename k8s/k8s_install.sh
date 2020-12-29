#https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
#安装docker，k8s官方建议安装docker18.09版本
## Create /etc/docker
sudo mkdir /etc/docker


# Set up the Docker daemon
cat <<EOF | sudo tee /etc/docker/daemon.json
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


# Create /etc/systemd/system/docker.service.d
sudo mkdir -p /etc/systemd/system/docker.service.d


# Restart Docker
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# 将 SELinux 设置为 permissive 模式（相当于将其禁用）
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

systemctl enable --now kubelet


#CentOS 7可能遇到由于iptables被绕过而导致流量无法正确路由的问题
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system


#拉镜像，再重新tag
docker pull gotok8s/kube-apiserver:v1.20.1
docker pull gotok8s/kube-controller-manager:v1.20.1
docker pull gotok8s/kube-scheduler:v1.20.1
docker pull gotok8s/kube-proxy:v1.20.1
docker pull gotok8s/pause:3.2
docker pull gotok8s/etcd:3.4.13-0
docker pull coredns/coredns:1.7.0

docker tag gotok8s/kube-apiserver:v1.20.1 k8s.gcr.io/kube-apiserver:v1.20.1
docker tag gotok8s/kube-controller-manager:v1.20.1 k8s.gcr.io/kube-controller-manager:v1.20.1
docker tag gotok8s/kube-scheduler:v1.20.1 k8s.gcr.io/kube-scheduler:v1.20.1
docker tag gotok8s/kube-proxy:v1.20.1 k8s.gcr.io/kube-proxy:v1.20.1
docker tag gotok8s/pause:3.2 k8s.gcr.io/pause:3.2
docker tag gotok8s/etcd:3.4.13-0 k8s.gcr.io/etcd:3.4.13-0
docker tag coredns/coredns:1.7.0  k8s.gcr.io/coredns:1.7.0 


#初始化控制平面
kubeadm init --control-plane-endpoint "loadblance:6443" --upload-certs


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

#添加admin用户
vi dashboard-adminuser.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system

kubectl create -f dashboard-adminuser.yaml

#绑定admin用户组
vi admin-user-role-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system

kubectl create -f admin-user-role-binding.yaml

#访问URL
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

#获取token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')

kubectl proxy --address='0.0.0.0'  --accept-hosts='^*$'

eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuLXdycWxnIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIwYWZhMTk4MS1hNWQ3LTRiZDItOGY3Ni1jOTZiYTA3MzFmYWUiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06YWRtaW4tdXNlciJ9.mfN7QOkZy6I4VJWGQNFPcDy7Wdv4N7EQzaOmyV-PLAVFTPNekfgJbUZu3ZBAa5VoH_OudXRKgT9ZnIlQwxSWJyENQyWrYt_2qcySF0xB8-TmxeNRyTkDIX44bocuTaqbVAkCyS1M3QOPga7DTBXEd9k65hRvmRbYMF5c8LDjoIlVlO51Pql8-vzLwR5Yo7PWKgQqr_gw6LHe6ciwJ7plVfsVDH7nM9LSAOeuvEvzcre0ERcunDh6ueGbBrC3vWOqRH6-Gl1mucsRC_e-WIqOYx78Q7nkB-48ynVtGfoy6cFdzryNIPvyRvYqO4y7_VO6O3uZo6rU3_o4jrSq0jFqfQ