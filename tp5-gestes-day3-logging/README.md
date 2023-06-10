## Stack Logging

### Logging Operator
The following command will deploy the logging and elasticsearch operators on the cluster.

```sh
cd ~/openshift-administrator-training/tp5-gestes-day3-logging/logging
kustomize build | oc apply -f - 
```

### Cluster logging instance
The following logging instance will be created in order to provide observability inside the cluster. 

```sh 
oc apply -f cluster-logging-instance.yaml
```