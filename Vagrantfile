# -*- mode: ruby -*-
# vi: set ft=ruby :
#
#
#
# Pospose : Vagrant script provisions a kubernetes cluster with 1 master node and 1 worker node
#
# Using yaml to load external configuration files
require 'yaml'
require 'fileutils'

$install_docker = <<-SCRIPT

echo "--- Executing script install_docker" 

echo "--- Installing docker util packages"
sudo yum install -y yum-utils device-mapper-persistent-data lvm2 | tee -a /data/$cluster/init_master.log
sudo yum install -y ca-certificates curl net-tools 2>&1 | tee -a /data/$cluster/init_master.log


echo "--- Add Docker’s official GPG key"
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

echo "--- List stable repository for docker"
sudo yum list docker-ce.x86_64 --showduplicates | sort -r | grep 19.

echo "--- Installing docker"
sudo yum install -y docker-ce-19.03.0

echo "--- Starting docker"
sudo systemctl enable docker
sudo systemctl start docker

echo "--- Cheking docker"
sudo docker version

echo "--- Update docker cgroup driver"
sudo tee  /etc/docker/daemon.json  << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

echo "--- Restart docker"
sudo systemctl restart docker

SCRIPT

$install_kubeadm = <<-SCRIPT

echo "--- Executing script install_kubeadm" 

echo "--- Update apt respository to stable kubernetes"

sudo tee /etc/yum.repos.d/kubernetes.repo <<  EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

echo "--- Checking available version of kubeadm"
echo "installing version $(curl -s https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages | grep Version | grep 1.17 | awk '{print $2}')"

echo "--- Installing Kubeadm and kubelet - version 1.17.0"
#sudo yum install -y kubeadm-1.17.3 kubelet-1.17.3  kubectl-1.17.3
sudo yum install -y kubelet kubeadm kubectl

echo "--- enable kubelet service"
sudo systemctl enable kubelet

SCRIPT


$preconfig = <<-SCRIPT

echo "--- Checking versions and IPs"

echo "HOME            $HOME"
echo "user            $(whoami)"
echo "docker  version $(sudo docker version)"
echo "kubelet version $(sudo kubelet --version)"
echo "kubeadm version $(sudo kubeadm version)"

IPADDR_ENP0S8=$(ifconfig eth1 | grep inet | grep broadcast | awk '{print $2}')
HOST_NAME=$(hostname -f)

echo "IPADDR_ENP0S8 $IPADDR_ENP0S8"
echo "HOST_NAME $HOST_NAME"

echo "--- Disable Swap "
sudo swapoff -a
sudo sed -i  '/ swap / s~^~#~g' /etc/fstab

echo "--- update cgroup driver"
echo "Environment=\"cgroup-driver=systemd\"" | sudo tee -a /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf

echo "Environment=\"KUBELET_EXTRA_ARGS=--node-ip=$IPADDR_ENP0S8\"" | sudo tee -a /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf

echo "--- etc/hosts file to comment ip6"
sudo sed -i '/ip6/s/^/#/' /etc/hosts

echo "--- update firewall to allow connection if enabled"

# open ports if firewall is enabed to allow pos to pod inter communication
#sudo firewall-cmd --permanent --add-port=6443/tcp
#sudo firewall-cmd --permanent --add-port=2379-2380/tcp
#sudo firewall-cmd --permanent --add-port=10250/tcp
#sudo firewall-cmd --permanent --add-port=10251/tcp
#sudo firewall-cmd --permanent --add-port=10252/tcp
#sudo firewall-cmd --permanent --add-port=10255/tcp
#sudo firewall-cmd –-reload

echo "--- update bridge-nf-call-iptables"
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl --system

echo "--- Virtual Extensible LAN (VxLAN) "
sudo modprobe br_netfilter

SCRIPT


$init_master = <<-SCRIPT

echo "--- Executing script init_master" 

echo "--- pull config images"
sudo kubeadm config images pull

echo "--- Export variables"
HOST_NAME=$(hostname -f)
IPADDR_ENP0S8=$(ifconfig eth1 | grep inet | grep broadcast | awk '{print $2}')

echo "--- Initialise kubeadm"
sudo kubeadm init  --apiserver-advertise-address=$IPADDR_ENP0S8 --apiserver-cert-extra-sans=$IPADDR_ENP0S8  --node-name $HOST_NAME  --pod-network-cidr 10.10.0.0/16 --service-cidr  10.150.0.0/16  2>&1 | tee -a /data/$cluster/init_master.log

echo "--- create dummy bootstart if not exist"
[ -f /etc/kubernetes/bootstrap-kubelet.conf ] || sudo touch /etc/kubernetes/bootstrap-kubelet.conf

echo "--- Export token for Worker Node"
sudo kubeadm token create --print-join-command > /data/$cluster/kubeadm_join_cmd.sh

SCRIPT


$config_master = <<-SCRIPT

echo "--- Executing script post_master" 

echo "--- Setup kubectl for vagrant user"
sudo mkdir /root/.kube/
sudo cp /etc/kubernetes/admin.conf /root/.kube/config

echo "--- Implement Calico for Kubernetes Networking"
echo "--- Projet calico : https://docs.projectcalico.org/v3.11/getting-started/kubernetes/"
sudo kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml

echo "--- Waiting for core dns pods to be up . . . "
while [ $(sudo kubectl get pods --all-namespaces | grep dns | grep Running | wc -l) != 2 ] ; do sleep 20 ; echo "--- Waiting for core dns pods to be up . . . " ; done

while [ $(sudo kubectl get nodes | grep master | grep Ready | wc -l) != 1 ] ; do sleep 20 ; echo "--- Waiting node to be ready . . . " ; done
echo "--- Matser node is Ready"
echo "`sudo kubectl get nodes`"

echo "--- Copy kube config to shared kubeadm install path"
sudo cp /etc/kubernetes/admin.conf /data/$cluster/config

SCRIPT


$init_worker = <<-SCRIPT

echo "--- Executing script init_worker"

echo "--- Install nfs common package for Storage"
sudo yum install nfs-utils -y 

echo "--- Join as worker node "
sudo chmod +x /data/$cluster/kubeadm_join_cmd.sh
sudo sh /data/$cluster/kubeadm_join_cmd.sh

echo "--- create dummy bootstart if not exist"
[ -f /etc/kubernetes/bootstrap-kubelet.conf ] || sudo touch /etc/kubernetes/bootstrap-kubelet.conf

SCRIPT

$init_proxy = <<-SCRIPT

echo "--- Executing script init_proxy"

echo "--- Disable selinux "
sudo setenforce 0
sudo sed -i 's~^SELINUX=~#&~' /etc/selinux/config  
echo "SELINUX=disabled" | sudo tee -a /etc/selinux/config 


echo "--- Update apt and install haproxy"
sudo yum install -y haproxy
sudo systemctl enable haproxy

echo "--- Update haproxy config"
sudo tee -a /etc/haproxy/haproxy.cfg << EOF
#### Config of Ingress Traffic to Kubernetes

frontend localhost
    bind *:443
    option tcplog
    mode tcp
    default_backend nodes
backend nodes
    mode tcp
    balance roundrobin
    option ssl-hello-chk
    server node01 192.168.205.42:30001 check
    server node02 192.168.205.43:30001 check

####END of Config
EOF

echo "--- Check haproxy config status"
haproxy -f /etc/haproxy/haproxy.cfg -c -V

echo "--- Restarting haproxy service"
sudo systemctl stop haproxy
sleep 5
sudo systemctl start haproxy

SCRIPT



$init_nfs = <<-SCRIPT

echo "--- Executing script init_proxy"

echo "--- Install nfs server for Storage"
sudo yum install nfs-utils -y 

sudo chkconfig nfs on
sudo service rpcbind start
sudo service nfs start
sudo service nfslock start

sudo systemctl status nfs

echo "--- Create nfs shared directory"
sudo mkdir /nfs/kubedata -p

echo "--- Change owernship"
sudo chown nobody:nobody /nfs/kubedata

echo "--- Update exports file"
sudo tee -a /etc/exports << EOF
/nfs/kubedata    *(rw,sync,no_subtree_check,no_root_squash,no_all_squash,insecure)
EOF

sudo exportfs -a
sudo exportfs -rva

echo "--- Restar nfs server and check status"
sudo systemctl restart nfs
sudo systemctl status nfs

SCRIPT


Vagrant.configure("2") do |config|
  # Using the hostmanager vagrant plugin to update the host files
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = true
  config.hostmanager.ignore_private_ip = false
  
  # Create a data dir to mount with in the VM information
  dirname = File.dirname("./../data/")
  unless File.directory?(dirname)
  FileUtils.mkdir_p(dirname)
  end
  
  # Loading in the VM configuration information
  servers = YAML.load_file('servers.yaml')
  
  servers.each do |servers| 
    config.vm.define servers["name"] do |srv|
      srv.vm.box = servers["box"] # Speciy the name of the Vagrant box file to use
      srv.vm.hostname = servers["name"] # Set the hostname of the VM
#     Add a second adapater with a specified IP
      srv.vm.network "private_network", ip: servers["ip"], :adapater=>2 
#     srv.vm.network :forwarded_port, guest: 22, host: servers["port"] # Add a port forwarding rule
      srv.vm.synced_folder ".", "/vagrant", type: "virtualbox"
      srv.vm.synced_folder "./../data/" , "/data", type: "virtualbox", owner: "root", group: "root"
	  
      srv.vm.provider "virtualbox" do |vb|
        vb.name = servers["name"] # Name of the VM in VirtualBox
        vb.cpus = servers["cpus"] # How many CPUs to allocate to the VM
        vb.memory = servers["memory"] # How much memory to allocate to the VM
#       vb.customize ["modifyvm", :id, "--cpuexecutioncap", "10"] # Limit to VM to 10% of available 
      end
	  
      srv.vm.provision "shell", inline: <<-SHELL
	  echo "set env variable"
	  echo cluster=cluster-centos | sudo tee -a /etc/environment 
	  . /etc/environment 
	  
	  echo "creating installation directory"
	  sudo mkdir -p /data/$cluster/
      	  	 
	  echo "--- Updating yum packages"
      sudo yum update -y 2>&1 | sudo tee -a /data/$cluster/yum-update.log

	  SHELL

	  
	  	  
      if servers["name"].include? "master" then
	    srv.vm.provision "shell", inline: $install_docker
        srv.vm.provision "shell", inline: $install_kubeadm
        srv.vm.provision "shell", inline: $preconfig
        srv.vm.provision "shell", inline: $init_master
        srv.vm.provision "shell", inline: $config_master	
        srv.vm.provision "shell", inline: $init_proxy
        srv.vm.provision "shell", inline: $init_nfs
      end
	  
      if servers["name"].include? "worker" then
        srv.vm.provision "shell", inline: $install_docker
        srv.vm.provision "shell", inline: $install_kubeadm
        srv.vm.provision "shell", inline: $preconfig
        srv.vm.provision "shell", inline: $init_worker
      end
	 
   end
 end
end