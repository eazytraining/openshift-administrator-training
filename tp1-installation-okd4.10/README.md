## Basic configuration for the Bastion server

The below steps are performed from the host server (KVM hypervisor)

Provide the basic server installation for the Bastion server
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

Deploy the basic configuration to the Bastion server
```sh
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



6. Download [config files](https://github.com/ObieBent/okd-upi-install) for each of the services
```sh
cd ~
git clone https://github.com/eazytraining/openshift-administrator-training.git
```
