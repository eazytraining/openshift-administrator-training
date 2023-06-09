#!/bin/sh 
declare -r NAMESPACE=${NAMESPACE:-eazytraining}

_log() {
    local level=$1; shift
    echo -e "$level: $@"
}

log_err() {
    _log "ERROR" "$@" >&2
}

info() {
    _log "\nINFO" "$@"
}

err() {
    local code=$1; shift
    local msg="$@"; shift
    log_err $msg
    exit $code
}


# Delete all resources in this namespace 
oc -n "$NAMESPACE" delete route.route.openshift.io/route-eazytraining-httpd
sleep 5

oc -n "$NAMESPACE" delete service/svc-eazytraining-httpd 
sleep 5 

oc -n "$NAMESPACE" delete imagestream.image.openshift.io/dck_eazytraining-lab-http 
sleep 5

oc -n "$NAMESPACE" delete buildconfig.build.openshift.io/dck-eazytraining-lab-http-1.0
sleep 5

oc -n "$NAMESPACE" delete deploymentconfig.apps.openshift.io/dc-eazytraining-httpd 
sleep 5

oc delete ns "$NAMESPACE"
