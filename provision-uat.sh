echo "--- Checking vagrant plugin"
[ $(vagrant plugin list | grep vagrant-hostmanager | wc -l) != 1 ] && vagrant plugin install vagrant-hostmanager 
[ $(vagrant plugin list | grep vagrant-vbguest | wc -l) != 1 ] && vagrant plugin install vagrant-vbguest


echo "--- creating data directory " 
mkdir -p ../data 

echo "--- provisioning cluster"
vagrant up

echo "--- copying config from cluster"
cp ../data/cluster-centos/config ~/.kube/

echo "--- labeling the nodes"
kubectl label node worker.uat.openkube.io node-role.kubernetes.io/worker=worker 
#kubectl label node worker.uat.openkube.io node-role.kubernetes.io/management=management  

echo "--- validating  the nodes"
kubectl get nodes
