#!/bin/bash

for node in ocp-bootstrap
do
   echo destroying $node ..
   virsh destroy $node
   virsh undefine $node --remove-all-storage
done

virsh list --all
