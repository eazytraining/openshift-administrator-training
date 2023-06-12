#!/bin/bash
# This starts the pipeline new-pipeline with a given 

set -e -u -o pipefail
declare -r SCRIPT_DIR=$(cd -P $(dirname $0) && pwd)
declare COMMAND="help"

GIT_URL=https://github.com/eazytraining/openshift-administrator-training.git
GIT_REVISION=main
PIPELINE=gitops-dev-pipeline
IMAGE_NAME=image-registry.openshift-image-registry.svc:5000/eazytraining/dck_eazytraining-lab-http:1.0
GIT_USER_NAME=ObieBent
GIT_PASSWORD=
TARGET_NAMESPACE=eazytraining

valid_command() {
  local fn=$1; shift
  [[ $(type -t "$fn") == "function" ]]
}

info() {
    printf "\n# INFO: $@\n"
}

err() {
  printf "\n# ERROR: $1\n"
  exit 1
}

command_help() {
  cat <<-EOF
  Starts a new pipeline in current kubernetes context

  Usage:
      pipeline.sh [command] [options]
  
  Examples:
      pipeline.sh init  # installs and creates all tasks, pvc and secrets
      pipeline.sh start -t art-eazytraining
      pipeline.sh logs
  
  COMMANDS:
      init                           creates ConfigMap, Tasks and Pipelines into current context
                                     it also creates a secret with -u/-p user/pwd for GitHub.com access
      start                          starts the given pipeline
      logs                           shows logs of the last pipeline run
      help                           Help about this command

  OPTIONS:
      -t, --target-namespace        Which target namespace to start the app ($TARGET_NAMESPACE)
      -g, --git-repo                Which quarkus repository to clone ($GIT_URL)
      -r, --git-revision            Which git revision to use ($GIT_REVISION)
      
EOF
}


while (( "$#" )); do
  case "$1" in
    start|logs|init)
      COMMAND=$1
      shift
      ;;
    -t|--target-namespace)
      TARGET_NAMESPACE=$2
      shift 2
      ;;
    -g|--git-repo)
      GIT_URL=$2
      shift 2
      ;;
    -r|--git-revision)
      GIT_REVISION=$2
      shift 2
      ;;
    -l|--pipeline)
      PIPELINE=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*|--*)
      command_help
      err "Error: Unsupported flag $1"
      ;;
    *) 
      break
  esac
done


command_init() {
  # This script imports the necessary files into the current project 
  
  oc apply -f infra/ns.yaml
  oc apply -f infra/pvc.yaml
  oc apply -f infra/sa.yaml
  oc apply -f infra/route-elistener.yaml

  oc apply -f misc/elistener.yaml
  oc apply -f misc/trigger.yaml

  oc apply -f tkn-tasks/extract-digest-task.yaml

  oc apply -f tkn-tasks/git-update-deployment.yaml

  oc apply -f pipelines/tekton-pipeline.yaml

}


command_logs() {
    tkn pr logs -f -L
}

command_start() {
  cat > /tmp/pipelinerun.yaml <<-EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: $PIPELINE-run-$(date "+%Y%m%d-%H%M%S")
spec:
  params:
    - name: git-url
      value: '$GIT_URL'
    - name: git-revision
      value: $GIT_REVISION
    - name: image-name
      value: $IMAGE_NAME
    - name: target-namespace
      value: $TARGET_NAMESPACE
    - name: git-username
      value: $GIT_USER_NAME
    - name: git-password
      value: $GIT_PASSWORD
  workspaces:
    - name: shared-workspace
      persistentVolumeClaim:
        claimName: builder-pvc
    - name: git-update-workspace
      persistentVolumeClaim:
        claimName: git-update-pvc
    - name: git-credentials
      secret: 
        secretName: git-ssh-key
    
        
  pipelineRef:
    name: $PIPELINE
  serviceAccountName: pipeline-bot
EOF

    oc apply -f /tmp/pipelinerun.yaml
}

main() {
  local fn="command_$COMMAND"
  valid_command "$fn" || {
    command_help
    err "invalid command '$COMMAND'"
  }

  cd $SCRIPT_DIR
  $fn
  return $?
}

main
