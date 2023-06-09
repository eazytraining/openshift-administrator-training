apiVersion: v1
baseDomain: eazytraining.lab
compute:
  - hyperthreading: Enabled
    name: worker
    replicas: 0 # Must be set to 0 for User Provisioned Installation as worker nodes will be manually deployed.
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: ${CLUSTER_NAME} # Cluster name
networking:
  clusterNetwork:
    - cidr: 10.128.0.0/14
      hostPrefix: 23
  networkType: OpenShiftSDN
  serviceNetwork:
    - 172.30.0.0/16
platform:
  none: {}
fips: false
pullSecret: '${PULL_SECRET}'
sshKey: '${SSH_KEY}'
additionalTrustBundle: | 
  ${REGISTRY_CERTIFICATE}
imageContentSources:
- mirrors:
  - local-registry.caas.eazytraining.lab:5000/okd
  source: quay.io/openshift/okd
- mirrors:
  - local-registry.caas.eazytraining.lab:5000/okd
  source: quay.io/openshift/okd-content