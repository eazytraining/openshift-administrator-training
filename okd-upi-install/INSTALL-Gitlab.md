This document provides detailed steps for installing Gitlab CE.  It is assumed to issue commands with the root user (EUID=0)


## Installation 

##### Dependencies installation 
```sh
dnf install -y policycoreutils-python3 curl openssh-server
```


##### Postfix service 
```sh
dnf install -y postfix
systemctl start postfix && systemctl enable --now postfix && systemctl status postfix
```


##### Add Gitlab repository
```sh
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash
```


##### Installation of gitlab ce package
```sh
EXTERNAL_URL="http://gitlab.eazytraining.lab" dnf -y install gitlab-ce
```


##### Firewall configuration
```sh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
systemctl reload firewalld
```


## Initial setup of Gitlab

It may need to get the initial password of root user account in the following file `/opt/gitlab/initial_root_password`.
Then, log in to the Gitlab instance **http://gitlab.eazytraining.lab** 