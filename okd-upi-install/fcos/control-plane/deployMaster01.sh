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
control_01_disk_creation() {
   info "Creating control-01 disk" 
   qemu-img create -o preallocation=metadata -f qcow2 /var/lib/libvirt/pool/ssd/ocp-control-01.caas.eazytraining.lab.qcow2 60G 
   sleep 15
}


# Control plane 01 Installation
control_01_installation() {
   info "Deploying Fedora CoreOS on the control-01 node"
   virt-install \
   --network network:ocpnet \
   --mac 52:54:00:3e:b7:f7\
   --name ocp-control-01 \
   --os-type=linux \
   --ram=10240 \
   --os-variant=fedora-coreos-stable \
   --vcpus=6 \
   --disk /var/lib/libvirt/pool/ssd/ocp-control-01.caas.eazytraining.lab.qcow2 --boot hd,menu=on\
   --nographics \
   --location=http://192.168.110.9:8080/okd4-image/ \
   --extra-args "rd.neednet=1 console=tty0 console=ttyS0,115200n8 coreos.inst=yes coreos.inst.install_dev=/dev/vda \
    coreos.live.rootfs_url=http://192.168.110.9:8080/okd4-image/fcos-37-rootfs.img coreos.inst.insecure=yes \
    coreos.inst.ignition_url=http://192.168.110.9:8080/ocp4/master.ign \
    ip=192.168.110.111::192.168.110.1:255.255.255.0:ocp-control-01.caas.eazytraining.lab:enp1s0:none nameserver=192.168.110.9"
}


control_01_disk_creation
control_01_installation