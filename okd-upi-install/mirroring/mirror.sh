#!/bin/bash

GODEBUG=X509ignoreCN=0
OCP_RELEASE='4.10.0-0.okd-2022-07-09-073606'
LOCAL_REGISTRY='local-registry.caas.eazytraining.lab:5000'
LOCAL_REPOSITORY='okd'
PRODUCT_REPO='openshift'
LOCAL_SECRET_JSON='/root/mirroring/pull-secret.json'
RELEASE_NAME='okd'
ARCHITECTURE='x86_64'

podman login registry.redhat.io --authfile $LOCAL_SECRET_JSON
podman login $LOCAL_REGISTRY --authfile $LOCAL_SECRET_JSON

oc adm -a ${LOCAL_SECRET_JSON} release mirror \
--from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE} \
--to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
--to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}