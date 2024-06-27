#!/bin/zsh

# ecs_mgr.zsh
# ECS Manager
# Author: Bret Ellis

# This script is used to manage ECS clusters/services
# The script uses the AWS CLI and jq to interact with ECS.
# It can:
#   - list all services in a cluster
#   - list all tasks for a service in a cluster
#   - list all task definitions for a service in a cluster
#   - list all task definitions for all services in a cluster
#   - start a service in a cluster
#   - stop a service in a cluster
#   - start all services in a cluster
#   - stop all services in a cluster
#
# Defaults:
#  - region: us-east-1 (valid values: us-east-1, sa-east-1, us-west-2)
#  - cluster: none
#  - service: none
#  - debug: false
#  - execute: none
#  - usage: false
#  - help: false
#  - dependencies: aws, jq


check_command() {
  if ! command -v $1 &> /dev/null; then
    echo "[ERROR] Command not found and required: $1"
    exit 1
  fi
}

check_dependencies () {
  check_command 'aws'
  check_command 'jq'
}

function usage() {
  echo "$0:"
  echo '-r|--region  <region>        one of: [us-east-1 | sa-east-1 | us-west-2] (default: us-east-1)'
  echo '-c|--cluster <cluster>'        
  echo '-s|--service <service>'
  echo '-d|--debug                   enable debug mode'
  echo '-e|--execute                 <subcommand>'
  echo
  echo '  subcommands:'
  echo '    list_services            list all services in a cluster'
  echo '    list_tasks               list all tasks for a service in a cluster'
  echo '    list_task_arns           list the task definitions for a service in a cluster'
  echo '    list_all_task_arns       list all task definitions for all services in a cluster'
  echo '    start                    start a service in a cluster'
  echo '    stop                     stop a service in a cluster'
  echo '    start_all                start all services in a cluster'
  echo '    stop_all                 stop all services in a cluster'
  echo
}

function parse_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  while (( $# )); do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      -r | --region)
        shift
        region=$1
        ;;
      -c | --cluster)
        shift
        cluster=$1
        ;;
      -s | --service)
        shift
        cluster_service=$1
        ;;
      -d | --debug)
        debug='true'
        ;;
      -e | --execute)
        shift
        execute=$1
        ;;
      *)
        echo "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

function list_services () {
  if [[ $debug == 'true' ]]; then
    echo "[DEBUG] listing services for cluster: $cluster"
  fi

  aws ecs list-services --region $region --cluster $cluster \
  | jq -r '.serviceArns[]' \
  | awk -F/ '{print $NF}' \
  | sort \
  | for i in $(cat) ; do echo $i ; done
}

function list_tasks () {
  if [[ $debug == 'true' ]]; then
    echo "[INFO] tasks for service: $cluster_service in cluster: $cluster"
  fi

  aws ecs list-tasks --region $region --cluster $cluster --service-name $cluster_service \
  | jq -r '.taskArns[]' \
  | awk -F/ '{print $NF}' \
  | sort \
  | for i in $(cat) ; do echo $i ; done
}

function list_task_arns () {
  if [[ $debug == 'true' ]]; then
    echo "[INFO] task arns for service: $cluster_service in cluster: $cluster"
  fi

  aws ecs describe-services --region $region --cluster $cluster --services $cluster_service \
  | jq -r '.services[].taskDefinition' \
  | awk -F/ '{print $NF}' \
  | sort \
  | for i in $(cat) ; do echo $i ; done
}

function list_all_task_arns () {
  if [[ $debug == 'true' ]]; then
    echo "[INFO] all task arns for cluster: $cluster"
  fi

  for svc in $(list_services); do
    aws ecs describe-services --region $region --cluster $cluster --services $svc \
    | jq -r '.services[].taskDefinition' \
    | awk -F/ '{print $NF}' \
    | for i in $(cat) ; do echo $i ; done
  done
}

function start () {
  if [[ $debug == 'true' ]]; then
    echo "[INFO] starting service: $cluster_service in cluster: $cluster"
  fi

  aws ecs update-service --service $cluster_service --cluster $cluster --desired-count 1
}

function stop () {
  if [[ $debug == 'true' ]]; then
    echo "[INFO] stopping service: $cluster_service in cluster: $cluster"
  fi

  aws ecs update-service --service $cluster_service --cluster $cluster --desired-count 0
}


function start_all () {
  if [[ $debug == 'true' ]]; then
    echo "[INFO] starting all services in cluster: $cluster"
  fi

  for service in $(list_services); do
    aws ecs update-service --service $service --cluster $cluster --desired-count 1 2>&1 >/dev/null
  done
}

function stop_all () {
  if [[ $debug == 'true' ]]; then
    echo "[INFO] stopping all services in cluster: $cluster"
  fi

  for service in $(list_services); do
    aws ecs update-service --service $service --cluster $cluster --desired-count 0 2>&1 >/dev/null
  done
}

check_dependencies

parse_args "$@"

if [[ region != 'us-east-1' && region != 'sa-east-1' && region != 'us-west-2' ]] ; then
  region='us-east-1'
fi

if [[ -z $region || -z $cluster || -z $execute ]] ; then
  usage
  exit 1
fi

if [[ $debug == 'true' ]]; then
  echo '[DEBUG] Arguments:'
  echo "region  : $region"
  echo "cluster : $cluster"
  echo "service : $cluster_service"
  echo "execute : $execute"
fi

case $execute in
  list_services|start_all|stop_all)
    $execute
  ;;

  list_tasks|list_task_arns|list_all_task_arns|start|stop)
    if [[ -z $cluster_service ]]; then
      echo '[ERROR] no service specified as arg. need one of -s|--service <service>'
      usage
      exit 99
    fi
    $execute
  ;;

  *)
    echo '[ERROR] invalid subcommand specified'
    usage
    exit 99
  ;;
esac
