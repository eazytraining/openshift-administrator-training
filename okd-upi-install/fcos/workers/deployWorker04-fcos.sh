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
worker_04_disk_creation() {
   info "Creating worker-04 disk"
   qemu-img create -o preallocation=metadata -f qcow2 /var/lib/libvirt/pool/ssd/ocp-worker-04.caas.eazytraining.lab.qcow2 60G
   sleep 15
}


# Worker 04 Installation
worker_04_installation() {
   info "Deploying Fedora CoreOS on the worker-04 node"
   virt-install \
   --network network:ocpnet \
   --mac 52:54:00:00:5a:70\
   --name ocp-worker-04 \
   --os-type=linux \
   --ram=12288 \
   --os-variant=rhel8.0 \
   --vcpus=8 \
   --disk /var/lib/libvirt/pool/ssd/ocp-worker-04.caas.eazytraining.lab.qcow2 --boot hd,menu=on\
   --nographics \
   --location=http://192.168.110.9:8080/okd4-image/ \
   --extra-args "rd.neednet=1 console=tty0 console=ttyS0,115200n8 coreos.inst=yes coreos.inst.install_dev=/dev/vda \
    coreos.live.rootfs_url=http://192.168.110.9:8080/okd4-image/fcos-37-rootfs.img coreos.inst.insecure=yes \
    coreos.inst.ignition_url=http://192.168.110.9:8080/ocp4/worker.ign \
    ip=192.168.110.117::192.168.110.1:255.255.255.0:ocp-worker-04.caas.eazytraining.lab:enp1s0:none nameserver=192.168.110.9"
}

worker_04_disk_creation
worker_04_installation