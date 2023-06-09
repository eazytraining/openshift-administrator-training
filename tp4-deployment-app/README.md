## Application deployment through S2I model. 

The script `s2i/sample-app-httpd/sample-app-httpd.sh` allows you to deploy a CI/CD pipeline based on the S2I approach. It will create the following resources : 
- namespace 
- build config
- deployment config 
- service
- route

The BuildConfig created have a webhook trigger (GitLab webhook) to control the circumstances in which the BuildConfig should be run. To configure the GitLab webhook, you should : 

- Create a secret with a reference to the webhook

```sh 
export BASE64_GITLAB_WEBHOOT_SECRET=<secret-in-base64>
export NAMESPACE=<target-namespace>

cat s2i/sample-app-httpd/openshift/templates/gitlab-secret-webhook.yaml | envsubst | oc apply -f -
```

- Describe the BuildConfig to get the webhook URL: 

```sh 
oc describe bc <name>
```
- Copy the webhook URL, replacing <secret> with your secret value.
- Follow the GitLab setup instructions (https://docs.gitlab.com/ce/user/project/integrations/webhooks.html#webhooks) to paste the webhook URL into your GitLab repository settings.


The script `s2i/sample-app-httpd/cleanall.sh` allows you to delete all the resources.  