## Basic configuration for the Bastion server

The below steps are performed from the host server (KVM hypervisor)

1. Provide the basic server installation for the Bastion server
```sh
mkdir -p ~/ansible/{roles,playbook} && cd ~/ansible/roles
```


Install ansible
```sh
dnf install -y epel-release
dnf install -y ansible
```

Confirm ansible installation
```sh
ansible --version
```

Define the ansible.cfg file
```sh
cat <<EOF  | tee ~/ansible/ansible.cfg
[defaults]
inventory 		= hosts
roles_path		= ./roles
gathering		= smart
host_key_checking	= False

[diff]
always = True
EOF
```

Define the hosts file
```sh
cat <<EOF | tee ~/ansible/hosts
[all]
bastion      ansible_host=192.168.110.9
gitlab       ansible_host=192.168.110.99
EOF
```

2. Deploy the basic configuration to the Bastion server
```sh
cp -r ~/openshift-administrator-training/okd-upi-install/ansible-roles/* ansible/roles
cp ~/openshift-administrator-training/okd-upi-install/manifests/basic-server.yaml ~/ansible/playbook
```

> Modify the playbook `basic-server.yaml`. Line 32 should contain the public ssh-key of the user that will have the sudo rights on the server


```sh
cd ~/ansible
ansible-playbook playbook/basic-server.yaml -l bastion -u root -k -v 
```


## Configure Environmental Services

1. SSH to the Bastion server

2. Update the OS and install required dependencies 
```sh 
dnf update
dnf install -y bind bind-utils dhcp-server httpd haproxy nfs-utils chrony vim jq wget git
```

3. Download Client and Installer tools  
```sh 
mkdir -p ~/ocp && cd ocp
wget https://github.com/okd-project/okd/releases/download/4.10.0-0.okd-2022-07-09-073606/openshift-client-linux-4.10.0-0.okd-2022-07-09-073606.tar.gz  -O openshift-client-linux.tar.gz
wget https://github.com/okd-project/okd/releases/download/4.10.0-0.okd-2022-07-09-073606/openshift-install-linux-4.10.0-0.okd-2022-07-09-073606.tar.gz -O openshift-install-linux.tar.gz
```

4. Extract Client and Installer tools and move them to /usr/local/bin
```sh 
# Client tools
tar xvf openshift-client-linux.tar.gz
mv oc kubectl /usr/local/bin

# Installer
tar xvf openshift-install-linux.tar.gz
mv openshift-install /usr/local/bin
```

5. Confirm Client and Installer tools are working 
```sh 
kubectl version --client --short
oc version
openshift-install version
```



6. Download [config files](https://github.com/eazytraining/openshift-administrator-training.git) for each of the services
```sh
cd ~
git clone https://github.com/eazytraining/openshift-administrator-training.git
```

7. Setup the mirroring registry for OKD (Air-gapped installation)
```sh
mkdir -p /shares/registry/{auth,certs,data}
```

Install `podman` and `httpd-tools`
```sh
dnf -y install podman httpd-tools skopeo
```

Prepare the csr answers
```sh
cd /shares/registry
cat <<EOF | tee /shares/registry/csr-answers
[req]
default_bits = 4096
default_md = sha256
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = FR
ST = Paris
L = Paris
O = Eazytraining
OU = Eazytraining Lab
CN = local-registry.caas.eazytraining.lab

[v3_ca]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints       = CA:true
keyUsage               = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign
issuerAltName          = issuer:copy
subjectAltName = @alt_names

[alt_names]
DNS.1 = local-registry.caas.eazytraining.lab
DNS.2 = ocp-svc.eazytraining.lab
EOF
```

Generate the self-signed certificate for the mirroring registry
```sh
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /shares/registry/certs/caas-eazytraining-lab.key -x509 -days 365 -out /shares/registry/certs/caas-eazytraining-lab.crt -config csr-answers
```

Trust the certificate
```sh
cp certs/caas-eazytraining-lab.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust 
trust list | grep -i 'local-registry.caas.eazytraining.lab'
```

Generate credentials for accessing to the registry
```sh
htpasswd -bBc /shares/registry/auth/htpasswd evreguser2 esbc_reg2099
```

Start the registry
```sh
podman run --name eazyregistry \
-p 5000:5000 \
-v /shares/registry/data:/var/lib/registry:z \
-v /shares/registry/auth:/auth:z \
-e "REGISTRY_AUTH=htpasswd" \
-e "REGISTRY_HTTP_SECRET=fetnmqf981la0eqoof3" \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
-e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
-v /shares/registry/certs:/certs:z \
-e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/caas-eazytraining-lab.crt" \
-e "REGISTRY_HTTP_TLS_KEY=/certs/caas-eazytraining-lab.key" \
-e "REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true" \
-d \
docker.io/library/registry:latest
```

Allow some firewall rules
```sh
firewall-cmd --add-port=5000/tcp --zone=internal --permanent
firewall-cmd --add-port=5000/tcp --zone=public --permanent
firewall-cmd --reload
```

Verify access to the registry
```sh
curl -u evreguser2:esbc_reg2099 https://local-registry.caas.eazytraining.lab:5000/v2/_catalog 
```

Log in to the registry with podman
```sh
podman login -u evreguser2 local-registry.caas.eazytraining.lab:5000
```

> Your credentials will be Base64 encoded into /run/containers/0/auth.json,  the content of this file should be added to your pull secret file.

Configure the mirroring 
```sh
cp -a ~/openshift-administrator-training/okd-upi-install/mirroring ~/
```

> Download your pull secret from Red Hat and place it into the ~/mirroring folder. Don't forget to add the content of the registry authentication file (/run/containers/0/auth.json)

```sh 
sh ~/mirroring/mirror.sh
```

Create the systemd unit file that can be used to control the container registry
```sh 
podman generate systemd --new --files --name eazyregistry
```

> This command will create a systemd unit file located in the current directory. The systemd unit file will ensure that the container is still running even after reboot of the server. 

```sh
# container-eazyregistry.service
# autogenerated by Podman 4.2.0

[Unit]
Description=Podman container-eazyregistry.service
Documentation=man:podman-generate-systemd(1)
Wants=network-online.target
After=network-online.target
RequiresMountsFor=%t/containers

[Service]
Environment=PODMAN_SYSTEMD_UNIT=%n
Restart=on-failure
TimeoutStopSec=70
ExecStartPre=/bin/rm -f %t/%n.ctr-id
ExecStart=/usr/bin/podman run \
	--cidfile=%t/%n.ctr-id \
	--cgroups=no-conmon \
	--rm \
	--sdnotify=conmon \
	--replace \
	--name eazyregistry \
	-p 5000:5000 \
	-v /shares/registry/data:/var/lib/registry:z \
	-v /shares/registry/auth:/auth:z \
	-e REGISTRY_AUTH=htpasswd \
	-e REGISTRY_HTTP_SECRET=fetnmqf981la0eqoof3 \
	-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
	-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
	-v /shares/registry/certs:/certs:z \
	-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/caas-eazytraining-lab.crt \
	-e REGISTRY_HTTP_TLS_KEY=/certs/caas-eazytraining-lab.key \
	-e REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true \
	-d docker.io/library/registry:latest
ExecStop=/usr/bin/podman stop --ignore --cidfile=%t/%n.ctr-id
ExecStopPost=/usr/bin/podman rm -f --ignore --cidfile=%t/%n.ctr-id
Type=notify
NotifyAccess=all

[Install]
WantedBy=default.target
```

Install the generated systemd unit file 
```sh
cp /root/container-eazyregistry.service /etc/systemd/system
systemctl enable container-eazyregistry.service
systemctl is-enabled container-eazyregistry.service
```

Restart the registry container
```sh 
systemctl restart container-eazyregistry.service
```

8. Configure BIND DNS

Apply configuration 
```sh
cp -f ~/openshift-administrator-training/okd-upi-install/dns/named.conf /etc/named.conf
cp -R ~/openshift-administrator-training/okd-upi-install/dns/zones /etc/named
```
  
Configure the firewall for DNS
```sh
firewall-cmd --add-port=53/udp --permanent
firewall-cmd --reload
```

Enable and start the service 
```sh 
systemctl enable --now named
systemctl start named 
systemctl status named
```

Confirm dig now sees the correct DNS results by using the DNS server running locally 
```sh 
dig eazytraining.lab @127.0.0.1
dig -x 192.168.110.9 @127.0.0.1
```

Change the nameserver configured in the `/etc/resolv.conf` by 127.0.0.1

9. Configure DHCP

Copy the conf file to the correct location for the DHCP service to use 
```sh
cp ~/openshift-administrator-training/okd-upi-install/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf
```

Configure the firewall 
```sh 
firewall-cmd --add-service=dhcp --permanent 
firewall-cmd --reload
```

Enable and start the service 
```sh 
systemctl enable --now dhcpd
systemctl start dhcpd 
systemctl status dhcpd
```

10. Configure the Apache Web Server 

Change default listen port to 8080 in httpd.conf
```sh
sed -i 's/Listen 80/Listen 0.0.0.0:8080/' /etc/httpd/conf/httpd.conf
```

Configure the firewall for Web Server traffic 
```sh
firewall-cmd --add-port=8080/tcp --permanent
firewall-cmd --reload
```

Enable and start the service 
```sh 
systemctl enable --now httpd
systemctl start httpd 
systemctl status httpd
```

Making a GET request to localhost on port 8080 should now return the default Apache webpage
```sh 
curl localhost:8080
```

11. Configure HAProxy 

Copy HAProxy config 
```sh
cp -f ~/openshift-administrator-training/okd-upi-install/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg
```

Configure the firewall 
```sh
firewall-cmd --add-port=9000/tcp
firewall-cmd --add-port=6443/tcp --zone=public --permanent # kube-api-server on control plane nodes
firewall-cmd --add-port=22623/tcp --zone=public --permanent # machine-config server
firewall-cmd --add-service=http --zone=public --permanent # web services hosted on worker nodes
firewall-cmd --add-service=https --zone=public --permanent # web services hosted on worker nodes
```

Enable and start the service 
```sh 
setsebool -P haproxy_connect_any 1 # SELinux name_bind access
systemctl enable --now haproxy
systemctl start haproxy 
systemctl status haproxy
```

12. Configure NFS for the OpenShift persistent storage. It is a requirement to provide storage to the Registry, empyDir can be specified if necessary. 

Create the Share 

Check available disk and its location `df -h`

```sh
dnf install nfs-utils -y
chown -R nobody:nobody /shares/
chmod -R 777 /shares/
```

Export the Share 
```sh 
echo "/shares 192.168.110.0/24(rw,sync,root_squash,no_subtree_check,no_wdelay)" > /etc/exports
exportfs -rv
```

Set firewall rules 
```sh 
firewall-cmd --zone=public --add-service mountd --permanent
firewall-cmd --zone=public --add-service rpc-bind --permanent
firewall-cmd --zone=public --add-service nfs --permanent
firewall-cmd --reload
```

Enable and start the NFS related services 
```sh
systemctl enable --now nfs-server rpcbind
systemctl start nfs-server rpcbind nfs-mountd
```

13. Configure NTP Server 
Set the NTP server 
```sh 
vim /etc/chrony.conf

# comment below line
# pool 2.almalinux.pool.ntp.org iburst

# add below lines
# Europe NTP servers
server 0.europe.pool.ntp.org
server 1.europe.pool.ntp.org
server 2.europe.pool.ntp.org
server 3.europe.pool.ntp.org

# Modify below line 
# Allow NTP client access from local network 
allow 192.168.110.0/24
```

Enable and start the NTP service
```sh
systemctl enable --now chronyd
systemctl start chronyd
systemctl status chronyd
```

Verify NTP Server 
```sh
chronyc sources
```

Allow remote access to NTP server
```sh 
firewall-cmd --permanent --add-service=ntp
firewall-cmd --reload
```

## Generate and host install files 
1. Generate an SSH key pair
```sh
ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
```

2. Create an install directory
```sh 
mkdir ~/ocp-install
```

3. Setup the install-config.yaml required for the installation
```sh
export CLUSTER_NAME=caas
export PULL_SECRET=`cat /root/mirroring/pull-secret.json`
export SSH_KEY=`cat /root/.ssh/id_rsa.pub`
export REGISTRY_CERTIFICATE=`cat /shares/registry/certs/caas-eazytraining-lab.crt`
```

```sh
cat ~/openshift-administrator-training/okd-upi-install/manifests/install-config.yaml.tpl | envsubst > ~/ocp-install/install-config.yaml
```


4. Check if the install-config yaml is populated as expected
```sh
vim ~/ocp-install/install-config.yaml
```

5. Generate Kubernetes manifest files
```sh
openshift-install create manifests --dir ~/ocp-install
```

>Above warning message says that master nodes are schedulable, it means we can have workload on control planes (control planes will also work as worker nodes). If you wish to disable this then run following sed command,
```sh
sed -i 's/mastersSchedulable: true/mastersSchedulable: false/' ~/ocp-install/manifests/cluster-scheduler-02-config.yml
```

Generate the Ignition config and Kubernetes auth files 
```sh
openshift-install create ignition-configs --dir ~/ocp-install/
```

6. Create a hosting directory to serve the configuration files for the OpenShift booting process
```sh
mkdir -p /var/www/html/ocp4
```

7. Copy all generated install files to the new web server directory 
```sh 
cp -R ~/ocp-install/*.ign /var/www/html/ocp4/
```

8. Move the Fedora Core OS image to the web server directory
```sh 
mkdir -p /var/www/html/okd4-image
wget https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/37.20230205.3.0/x86_64/fedora-coreos-37.20230205.3.0-live-kernel-x86_64 -O /var/www/html/okd4-image/fcos-37-vmlinuz
wget https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/37.20230205.3.0/x86_64/fedora-coreos-37.20230205.3.0-live-initramfs.x86_64.img -O /var/www/html/okd4-image/fcos-37-initramfs.img
wget https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/37.20230205.3.0/x86_64/fedora-coreos-37.20230205.3.0-live-rootfs.x86_64.img -O /var/www/html/okd4-image/fcos-37-rootfs.img
```

9. Create the .treeinfo file which will be used as a helper for installing the OS
```sh 
cat <<EOF > /var/www/html/okd4-image/.treeinfo
[general]
arch = x86_64
family = Fedora CoreOS
platforms = x86_64
version = 37
[images-x86_64]
initrd = fcos-37-initramfs.img
kernel = fcos-37-vmlinuz
EOF
```

10. Change ownership and permissions of the web server directory
```sh
# OS
chcon -R -t httpd_sys_content_t /var/www/html/okd4-image
chown -R apache: /var/www/html/okd4-image
chmod 744 -R /var/www/html/okd4-image/

# Ignition files
chcon -R -t httpd_sys_content_t /var/www/html/ocp4/
chown -R apache: /var/www/html/ocp4/
chmod 744 -R /var/www/html/ocp4/
```

11. Confirm you can see all files added to the /var/www/html/ocp4/ and /var/www/htlm/okd4-image/ dirs through Apache
```sh
curl localhost:8080/ocp4/
curl localhost:8080/okd4-image/
```

## Deploy OpenShift

1. Deploy the bootstrap host and the control plane hosts 
 
**From the KVM Hypervisor**

Clone the repository
```sh
git clone https://github.com/ObieBent/okd-upi-install.git
```

###### Open four terminal

```sh
cd ~/openshift-administrator-training/okd-upi-install
```

1st terminal
```sh 
sh fcos/control-plane/deployBootstrap.sh
```

2nd terminal
```sh 
sh fcos/control-plane/deployMaster01.sh
```

3rd terminal
```sh 
sh fcos/control-plane/deployMaster02.sh
```

4th terminal
```sh 
sh fcos/control-plane/deployMaster03.sh
```

## Monitor the Bootstrap Process
**From the Bastion host**
1. You can monitor the bootstrap process from the ocp-svc host at different log levels (debug, error, info)
```sh 
openshift-install --dir ~/ocp-install wait-for bootstrap-complete --log-level=debug
```

2. Once bootstrapping is complete the ocp-bootstrap node [can be removed](https://github.com/ObieBent/okd-upi-install#remove-the-bootstrap-node)


## Remove the Boostrap Node
1. Remove all references to the ocp-bootstrap host from the /etc/haproxy/haproxy.cfg file 
```sh 
# Two entries
vim /etc/haproxy/haproxy.cfg
# Restart HAProxy
systemctl reload haproxy
```

2. The ocp-bootstrap host can now be safely shutdown and deleted.
```sh
sh ~/openshift-administrator-training/okd-upi-install/cleanup-bootstrap.sh 
```



## Wait for installation to complete
1. Collect the OpenShift Console address and kubeadmin credentials from the output to the install-complete event
```sh
openshift-install --dir ~/ocp-install wait-for install-complete --log-level=debug
```
2. Continue to join the worker nodes to the cluster in a new tab whilst waiting for the above command to complete


## Join Worker Nodes

1. Setup 'oc' and 'kubectl' clients on the Bastion machine
```sh 
export KUBECONFIG=~/ocp-install/auth/kubeconfig
echo 'export OC_EDITOR="vim"' >> ~/.bashrc
echo 'export KUBE_EDITOR="vim"' >> ~/.bashrc
source ~/.bashrc
# Test auth by viewing cluster nodes
oc get nodes
```

###### Open again four terminal

```sh
cd ~/openshift-administrator-training/okd-upi-install
```

1st terminal
```sh 
sh fcos/workers/deployWorker01-fcos.sh
```

2nd terminal
```sh 
sh fcos/workers/deployWorker02-fcos.sh
```

3rd terminal
```sh 
sh fcos/workers/deployWorker03-fcos.sh
```

4th terminal
```sh 
sh fcos/workers/deployWorker04-fcos.sh
```

2. View and approve pending CSRs 
```sh
# View CSRs
oc get csr
# Approve all pending CSRs
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
# Wait for kubelet-serving CSRs and approve them too with the same command
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
```
3. Watch and wait for the Worker Nodes to join the cluster and enter a 'Ready' status

>This can take 5-10 minutes
```sh
watch -n5 oc get nodes