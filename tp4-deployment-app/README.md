## Application deployment through S2I model. 

The following script `s2i/sample-app-httpd/sample-app-httpd.sh` allows you to deploy a CI/CD pipeline based on the S2I approach. It will create the following resources : 
- namespace 
- build config
- deployment config 
- service
- route

The BuildConfig created have a webhook trigger (GitLab webhook) to control the circumstances in which the BuildConfig should be run. To configure the GitLab webhook, you should : 

- Create a secret with a reference to the webhook

```sh 
export BASE64_GITHUB_WEBHOOT_SECRET=<secret-in-base64>
export NAMESPACE=<target-namespace>

cat ~/openshift-administrator-training/tp4-deployment-app/s2i/sample-app-httpd/openshift/templates/gitlab-secret-webhook.yaml | envsubst | oc apply -f -
```

- Describe the BuildConfig to get the webhook URL: 

```sh 
oc describe bc <name>
```
- Copy the webhook URL, replacing <secret> with your secret value.
- Follow the [GitLab setup instructions](https://docs.github.com/en/webhooks-and-events/webhooks/creating-webhooks) to paste the webhook URL into your GitLab repository settings.


The script `s2i/sample-app-httpd/cleanall.sh` allows you to delete all the resources.  


## Application deployment through Gitops model 

### Operators installation

#### Build the Operators Catalog Source 

Required tool: 
- [opm](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.10.0/opm-linux-4.10.0.tar.gz)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/)

Disable the default OperatorHub sources
```sh
oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
```

```sh 
# download and extract the opm utility
cd ~/ocp && wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.10.0/opm-linux-4.10.0.tar.gz
tar -zxf opm-linux-4.10.0.tar.gz
mv opm /usr/local/bin/

# check if opm is installed
opm version
```

Authenticate with registry.redhat.io 
```sh 
podman login registry.redhat.io --authfile /root/mirroring/pull-secret.json
```

Authenticate with the target registry
```sh
podman login local-registry.caas.eazytraining.lab:5000 --authfile /root/mirroring/pull-secret.json
```

Prune the source index of all but the specified packages
```sh
opm index prune \
-f registry.redhat.io/redhat/redhat-operator-index:v4.10 \
-p cluster-logging,openshift-gitops-operator,elasticsearch-operator\
,devspaces,devworkspace-operator,serverless-operator,servicemeshoperator\
,openshift-pipelines-operator-rh,vertical-pod-autoscaler,redhat-oadp-operator\
,kiali-ossm,jaeger-product,cincinnati-operator \
-t local-registry.caas.eazytraining.lab:5000/olm/redhat-operator-index:v4.10
```

Push the new index image to the target registry
```sh
podman push local-registry.caas.eazytraining.lab:5000/olm/redhat-operator-index:v4.10
```

Add the catalog source to the cluster
```sh 
oc apply -f ~/openshift-administrator-training/okd-upi-install/manifests/catalogSource.yaml
```


#### OpenShift Pipelines 
```sh 
cd ~/openshift-administrator-training/tp4-deployment-app/cicd/operators/pipelines
kustomize build | oc apply -f - 
```

After issuing these commands, please proceed to the InstallPlan manual approval. 


#### OpenShift GitOps 
```sh 
cd ~/openshift-administrator-training/tp4-deployment-app/cicd/operators/gitops
kustomize build | oc apply -f - 
```

After issuing these commands, please proceed to the InstallPlan manual approval. The installation of this operator will create implicitly a new namespace `openshift-gitops` where control plane workloads would be instantiated. 
It may be necessary to check if pods are running properly. 

##### Day2 prerequisites

Manifests located into day2 folder set up the following features: 
- Swicthing of control plane workloads on infra nodes
- RBAC for eazytraining-admin users group


### Application Deployment 

#### Build & Push

The following script `cicd/tekton/pipeline.sh` deploy several required resources for building the CI pipeline. 


1. Deploy the necessary files into the current project 

```sh
sh cicd/tekton/pipeline.sh init 
```

Before proceeding to the launch of the first pipeline run, it may be necessary to configure the secrets required for the service account `pipeline-bot`

```sh
export GITHUB_HOST_FQDN=<gitlab-server-fqdn>
export BASE64_PRIVATE_SSH_KEY=<ssh-private-key-user-base64>
export BASE64_KNOWN_HOSTS=<ssh-public-key-gitlab-base64>

export GIT_USERNAME=<clear-username>
export GIT_PASSWORD=<clear-password>

cat cicd/tekton/infra/secret-ssh-yaml | envsubst | oc apply -f - 
cat cicd/tekton/infra/secret-basic-auth.yaml | envsubst | oc apply -f - 
```

2. Trigger manually a PipelineRun

```sh 
sh cicd/tekton/pipeline.sh start
```

In order to control the circumstances in which the tekton pipeline should run, a webhook configured at the GitLab server is mandatory. To configure the GitLab webhook, you should : 

- Get the host URL of the EventListener (`oc get route <eventlistener-name> -n <target-namespace> -o json | jq -r '.spec.host'`)
- Copy the host URL of the EventListener and follow the [GitLab setup instructions](https://docs.github.com/en/webhooks-and-events/webhooks/creating-webhooks) to paste the webhook URL into your GitLab repository settings.


#### Deployment 

Create the ArgoCD application for deployment the application. 

```sh 
oc apply -f ~/openshift-administrator-training/tp4-deployment-app/argo/app.yaml
```