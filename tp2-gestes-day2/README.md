## Day 2 Gestures

### Configure storage for the Image Registry
1. Clone the CSI driver repository required in order to consume NFS volumes

```sh 
mkdir ~/ocp/nfs -p && cd ~/ocp/nfs
git clone https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner.git k8s-csi-nfs 
cd k8s-csi-nfs 
```

2. Create namespace for NFS Storage provisioner
```sh
oc create namespace openshift-nfs-storage
```

3. Add monitoring label to namespace
```sh 
oc label namespace openshift-nfs-storage "openshift.io/cluster-monitoring=true"
```

4. Configure deployment and RBAC for NFS <br>

Switch project 
```sh
oc project openshift-nfs-storage
```

Change namespace on deployment and rbac YAML file
```sh
NAMESPACE=`oc project -q`

sed -i'' "s/namespace:.*/namespace: $NAMESPACE/g" ./deploy/rbac.yaml 
sed -i'' "s/namespace:.*/namespace: $NAMESPACE/g" ./deploy/deployment.yaml
```

Create RBAC
```sh
oc create -f deploy/rbac.yaml
oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:$NAMESPACE:nfs-client-provisioner
```

Configure deployment
```sh
vim ~/ocp/nfs/k8s-csi-nfs/deploy/deployment.yaml
```

```yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: openshift-nfs-storage
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: quay.io/external_storage/nfs-client-provisioner:latest
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: storage.io/nfs
            - name: NFS_SERVER
              value: 10.10.51.9           # Change this (NFS IP Server )
            - name: NFS_PATH
              value: /mnt/nfs_shares/okd  # Change this (NFS mount path)
      volumes:
        - name: nfs-client-root
          nfs:
            server: 10.10.51.9            # Change this (NFS IP Server)
            path: /mnt/nfs_shares/okd     # Change this (NFS mount path)
```

Configure Storage Class
```sh
vim ~/ocp/nfs/k8s-csi-nfs/deploy/class.yaml
```

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
provisioner: storage.io/nfs # or choose another name, must match deployment's env PROVISIONER_NAME'
parameters:
  archiveOnDelete: "false"
```

Deploy Deployment and Storage Class
```sh
oc create -f ~/ocp/nfs/k8s-csi-nfs/deploy/class.yaml 
oc create -f ~/ocp/nfs/k8s-csi-nfs/deploy/deployment.yaml
```

Verify Deployment
```sh
oc get pods -n openshift-nfs-storage
```

1. Create the 'image-registry-storage' PVC by updating the Image Registry operator config by updating the management state to 'Managed' and adding 'pvc' and 'claim' keys in the storage key:

```sh
oc edit configs.imageregistry.operator.openshift.io
```

```sh
managementState: Managed
```

```sh 
storage:
  pvc:
    claim: # leave the claim blank
```

2. Confirm the 'image-registry-storage' pvc has been created and is currently in a 'Pending' state
```sh 
oc get pvc -n openshift-image-registry
```

3. Create the persistent volume for the 'image-registry-storage' pvc to bind to
```sh
export REGISTRY_SIZE=100
export REGISTRY_PV_NAME=registry-pv
cat  ~/openshift-administrator-training/okd-upi-install/manifests/registry-pv.yaml | envsubst | oc create -f -
```

4. After a short wait the 'image-registry-storage' pvc should now be bound
```sh
oc get pvc -n openshift-image-registry
```

5. Set default storageclass

```sh
oc patch storageclass managed-nfs-storage -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
```

6. Check clusteroperator status. Wait until Availability become True.
```sh
oc get clusteroperator image-registry
```


### Access the OpenShift Console
1. Wait for the 'console' Cluster Operator to become available
> There will be a redeployment of the following cluster operators: kube-apiserver & openshift-apiserver

```sh 
oc get clusteroperators
```

2. Append the following to your local workstations /etc/hosts file:
> From your local workstation If you do not want to add an entry for each new service made available on OpenShift you can configure the ocp-svc DNS server to serve externally and create a wildcard entry for *.apps.caas.eazytraining.lab

```sh
# Open the hosts file
sudo vi /etc/hosts

# Append the following entries:
192.168.110.9 bastion api.caas.eazytraining.lab console-openshift-console.apps.caas.eazytraining.lab oauth-openshift.apps.caas.eazytraining.lab downloads-openshift-console.apps.caas.eazytraining.lab alertmanager-main-openshift-monitoring.apps.caas.eazytraining.lab grafana-openshift-monitoring.apps.caas.eazytraining.lab prometheus-k8s-openshift-monitoring.apps.caas.eazytraining.lab thanos-querier-openshift-monitoring.apps.caas.eazytraining.lab
```

3. Navigate to the OpenShift Console URL and log in as the 'username' user

>You will get self signed certificate warnings that you can ignore If you need to login as kubeadmin and need to the password again you can retrieve it with: cat ~/ocp-install/auth/kubeadmin-password


### Infra Nodes Configuration 
1. Adding the label `node-role.kubernetes.io/infra`
```sh 
oc  label node ocp-worker-01.caas.eazytraining.lab node-role.kubernetes.io/infra=
oc  label node ocp-worker-02.caas.eazytraining.lab node-role.kubernetes.io/infra=
oc  label node ocp-worker-03.caas.eazytraining.lab node-role.kubernetes.io/infra=
```

2. Define the machine config pool configuration dedicated to the Infra Nodes
```sh
mkdir ~/ocp/infra-nodes 
```

```sh
cat <<EOF | sudo tee  ~/ocp/infra-nodes/mcp.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: infra
spec:
  machineConfigSelector:
    matchExpressions:
      - {key: machineconfiguration.openshift.io/role, operator: In, values: [worker,infra]}
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/infra: ""
EOF
```

3. Apply the machine config pool configuration
```sh
oc apply -f ~/ocp/infra-nodes/mcp.yaml
```

4. Check the machine config pool `infra` status

```sh
watch -n2 oc get mcp
```

5. Schedule the ingress controller pods on infra nodes 
```sh 
oc edit ingresscontrollers.operator.openshift.io -n openshift-ingress-operator
```

```sh 
spec: 
  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/infra: ""
```

Verify if ingress controller pods are running on infra nodes 
```sh 
oc get pod -n openshift-ingress -o wide
```

6. Schedule the image registry pods on infra nodes
```sh
oc edit configs.imageregistry.operator.openshift.io
```

```sh
spec:
 nodeSelector:
   node-role.kubernetes.io/infra: ""
```

Verify if image registry pods are running on infra nodes
```sh 
oc get po -n openshift-image-registry  -owide
```

7. Remove label node-role.kubernetes.io/worker
```sh
oc  label node ocp-worker-01.caas.eazytraining.lab node-role.kubernetes.io/worker-
oc  label node ocp-worker-02.caas.eazytraining.lab node-role.kubernetes.io/worker-
oc  label node ocp-worker-03.caas.eazytraining.lab node-role.kubernetes.io/worker-
```

### Monitoring
1. Define the scheduling of the monitoring stack pods on Infra Nodes at the cluster level and the required size on the storage

```sh 
export CLUSTER_NAME=caas
export NFS_MONITORING_SIZE=20Gi
export STORAGE_CLASS=`oc get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'`
cat  ~/openshift-administrator-training/okd-upi-install/manifests/monitoring-cluster.yaml | envsubst | oc apply -f - 
```

2. Enable monitoring for user-defined projects on Infra Nodes
```sh 
oc apply -f ~/openshift-administrator-training/okd-upi-install/manifests/monitoring-user.yaml
```