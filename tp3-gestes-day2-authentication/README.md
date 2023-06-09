# Day 2 Gestures

### Create the first Admin user
1. Apply the `oauth-htpasswd.yaml` file to the cluster

```sh
export HTPASSWD_SECRET_NAME=htpasswd-secret
export HTPASSWD_SECRET=`htpasswd -n -B -b <username> <password> | base64 -w0`
cat  ~/openshift-administrator-training/okd-upi-install/manifests/01-oauth-htpasswd.yaml | envsubst | oc apply -f -
cat  ~/openshift-administrator-training/okd-upi-install/manifests/02-oauth-htpasswd.yaml | envsubst | oc replace -f - 
```

2. Assign the new user admin permissions
```sh
export USER=<username>
cat  ~/openshift-administrator-training/okd-upi-install/manifests/rbac-user-admin.yaml | envsubst | oc create -f - 
```

3. Wait until the cluster operator `authentication` become available 
```sh 
watch -n5 oc get clusteroperators authentication
```

4. Log in to the Web Console with the username provided in Step 1

5. Remove the kubeadmin user 
```sh
oc delete secrets kubeadmin -n kube-system
```

> /!\ If you follow this procedure before another user is a cluster-admin, then the cluster must be reinstalled. It is not possible to undo this command.