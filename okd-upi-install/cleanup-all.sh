#!/bin/bash

for node in ocp-control-01 ocp-control-02 ocp-control-03 ocp-worker-01 ocp-worker-02 ocp-worker-03 ocp-worker-04
do
   echo destroying $node ..
   virsh destroy $node
   virsh undefine $node --remove-all-storage
done

virsh list --all
