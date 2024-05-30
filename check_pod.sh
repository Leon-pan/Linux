#!/bin/bash

namespace=$1
command=$2
pod=$(kubectl get pods -n $namespace | grep -v 'NAME' | grep "Running" | awk '{print $1}')

case $command in
help)
  echo "Usage: $0 {check|update|rollback|help}" >&2
  exit 0
  ;;
check)
  for i in $pod; do
    echo $1:$i $2 begin
    kubectl exec -it -n $namespace $i -- bash -c "uptime"
    echo "########done########"
  done
  exit 0
  ;;
update)
  for i in $pod; do
    echo $1:$i $2 begin
    #kubectl exec -it -n $namespace $i --  bash -c ""
    echo "########done########"
  done
  exit 0
  ;;
rollback)
  for i in $pod; do
    echo $1:$i $2 begin
    #kubectl exec -it -n $namespace $i --  bash -c ""
    echo "########done########"
  done
  exit 0
  ;;
*)
  echo "Usage: $0 {check|update|rollback|help}" >&2
  ;;

esac
