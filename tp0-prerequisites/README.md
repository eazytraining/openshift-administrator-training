# OpenShift 4 Install - User Provisioned Infrastructure (UPI)

## Architecture diagram
***

###### Information 
- Cluster name: caas
- Base Domain: eazytraining.lab 

![Diagram](../okd-upi-install/diagram/eazytraining-lab.png)

**OKD VMs**
|          VM             |  CPU | Memory |     OS            |    IP Address         | Disk (GB) |
|-------------------------|------|--------|-------------------|-----------------------|-----------|
|     Bastion             |   4  |    4   |  Alma Linux 8.8   |  192.168.110.9        |     450   |
|     Master-[1-3]        |   6  |    10  |  Fedora CoreOS 37 |  192.168.110.[111-113]|     60    |
|     Worker-[1-4]        |   8  |    12  |  Fedora CoreOS 37 |  192.168.110.[114-117]|     60    | 
|     Bootstrap           |   4  |    8   |  Fedora CoreOS 37 |  192.168.110.110      |     40    |


## Download Software
***

1. Download [Alma Linux 8.8](http://mirror.almalinux.ikoula.com/8.8/isos/x86_64/AlmaLinux-8.8-x86_64-minimal.iso) for installing the bastion node
2. Download the following files
    -  [FCOS 37 Build 37.20230205.3.0](https://builds.coreos.fedoraproject.org/browser?stream=stable&arch=x86_64)
        - [kernel](https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/37.20230205.3.0/x86_64/fedora-coreos-37.20230205.3.0-live-kernel-x86_64)
        - [initramfs](https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/37.20230205.3.0/x86_64/fedora-coreos-37.20230205.3.0-live-initramfs.x86_64.img)
        - [rootfs](https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/37.20230205.3.0/x86_64/fedora-coreos-37.20230205.3.0-live-rootfs.x86_64.img)
    
3. Login to [Red Hat OpenShift Cluster Manager](https://cloud.redhat.com/openshift) to download the Pull Secret
4. Select 'Create Cluster' from the 'Clusters' navigation menu
5. Select 'RedHat OpenShift Container Platform
6. Select 'Run on Bare Metal'
7. Download the Pull Secret


## Prepare the environment for installing OKD 4.10
**In KVM Hypervisor**

All the below commands should be performed by using the root account. 

1. Install the KVM Hypervisor

Install all the dependencies 
```sh 
dnf install qemu-kvm libvirt libvirt-python3 jq libguestfs-tools virt-install vim git curl wget firewalld NetworkManager-tui -y
```

Enable and start the service
```sh
systemctl enable libvirtd && systemctl start libvirtd && systemctl status libvirtd
systemctl enable firewalld && systemctl start firewalld && systemctl status firewalld
```


2. Create the **ocpnet** network in KVM
```sh
mkdir ~/ocp && cd ocp
cat <<EOF  | tee ocpnet.xml
<network>
  <name>ocpnet</name>
  <forward mode='nat' dev='enp4s0'/>
  <bridge name='ocpnet'/>
  <ip address='192.168.110.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF
```

```sh
virsh net-define ocpnet.xml
virsh net-list --all
virsh net-autostart ocpnet
virsh net-start ocpnet
virsh net-list --all
virsh net-destroy default
virsh net-undefine default
systemctl restart libvirtd
```

3. Configure the network interfaces and the firewall 
```sh
service NetworkManager restart
nmcli connection modify ocpnet connection.zone internal
nmcli connection modify 'System enp4s0' connection.zone public
firewall-cmd --get-active-zones
firewall-cmd --zone=internal --add-masquerade --permanent
firewall-cmd --zone=public --add-masquerade --permanent
firewall-cmd --reload
firewall-cmd --list-all --zone=internal
firewall-cmd --list-all --zone=public
```

4. Download the Alma Linux 8.8 iso image to the dedicated pool on the host server. <br>
```sh
mkdir -p /var/lib/libvirt/pool/ssd/iso && cd /var/lib/libvirt/pool/ssd/iso
wget http://mirror.almalinux.ikoula.com/8.8/isos/x86_64/AlmaLinux-8.8-x86_64-minimal.iso
```

5. Create the Bastion node server and install Alma Linux 8.8

Clone the repository
```sh
cd ~ && git clone https://github.com/eazytraining/openshift-administrator-training.git
```

Copy the required Kickstart file to the / directory
```sh
cp ~/openshift-administrator-training/okd-upi-install/ks.cfg /
```

> To create an encrypted password, you can use python: 
```sh
python3 -c 'import crypt,getpass;pw=getpass.getpass();print(crypt.crypt(pw) if (pw==getpass.getpass("Confirm: ")) else exit())'
```

The encrypted password should be added in the kickstart file.

Install the Bastion server
```sh
sh ~/openshift-administrator-training/okd-upi-install/deployBastion.sh
```