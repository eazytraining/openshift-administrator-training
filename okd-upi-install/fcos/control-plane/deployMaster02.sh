#!/bin/bash 
set -e -u -o pipefail

_log() {
    local level=$1; shift
    echo -e "$level: $@"
}

info() {
    _log "\nINFO\n" "$@"
}


# Disk creation
control_02_disk_creation() {
   info "Creating control-02 disk" 
   qemu-img create -o preallocation=metadata -f qcow2 /var/lib/libvirt/pool/ssd/ocp-control-02.caas.eazytraining.lab.qcow2 60G 
   sleep 15
}

# Control Plane 02 Installation
control_02_installation() {
   info "Deploying Fedora CoreOS on the control-02 node"
   virt-install \
   --network network:ocpnet \
   --mac 52:54:00:0b:55:46\
   --name ocp-control-02 \
   --os-type=linux \
   --ram=10240 \
   --os-variant=fedora-coreos-stable \
   --vcpus=6 \
   --disk /var/lib/libvirt/pool/ssd/ocp-control-02.caas.eazytraining.lab.qcow2 --boot hd,menu=on\
   --nographics \
   --location=http://192.168.110.9:8080/okd4-image/ \
   --extra-args "rd.neednet=1 console=tty0 console=ttyS0,115200n8 coreos.inst=yes coreos.inst.install_dev=/dev/vda \
    coreos.live.rootfs_url=http://192.168.110.9:8080/okd4-image/fcos-37-rootfs.img coreos.inst.insecure=yes \
    coreos.inst.ignition_url=http://192.168.110.9:8080/ocp4/master.ign \
    ip=192.168.110.112::192.168.110.1:255.255.255.0:ocp-control-02.caas.eazytraining.lab:enp1s0:none nameserver=192.168.110.9"
}

control_02_disk_creation
control_02_installation
