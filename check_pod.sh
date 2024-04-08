#!/bin/bash

pod=$(kubectl get pods -n antstack | grep -v 'NAME' | grep spanner | grep "Running" | awk '{print "antstack="$1}')
command=$1

case $command in
help)
  echo "Usage: $0 {check|update|rollback|help}" >&2
  exit 0
  ;;
check)
  for i in $pod; do
    echo $i $0 begin
    ns=$(echo $i | awk -F'=' '{print $1}')
    pd=$(echo $i | awk -F'=' '{print $2}')
    kubectl exec -it -n $ns $pd -- bash -c "tail -n 1 /home/admin/spanner/logs/error.log|grep 'check protocol http error with peer'|grep '2024/03/22'"
    echo "########done########"
  done
  exit 0
  ;;
update)
  for i in $pod; do
    echo $i $0 begin
    ns=$(echo $i | awk -F'=' '{print $1}')
    pd=$(echo $i | awk -F'=' '{print $2}')
    #kubectl exec -it -n $ns $pd --  bash -c ""
    echo "########done########"
  done
  exit 0
  ;;
rollback)
  for i in $pod; do
    echo $i $0 begin
    ns=$(echo $i | awk -F'=' '{print $1}')
    pd=$(echo $i | awk -F'=' '{print $2}')
    #kubectl exec -it -n $ns $pd --  bash -c ""
    echo "########done########"
  done
  exit 0
  ;;
fasten)
  for i in $pod; do
    echo $i $0 begin
    ns=$(echo $i | awk -F'=' '{print $1}')
    pd=$(echo $i | awk -F'=' '{print $2}')
    #kubectl exec -it -n $ns $pd --  bash -c ""
    echo "########done########"
  done
  exit 0
  ;;
*)
  echo "Usage: $0 {check|update|rollback|help}" >&2
  ;;

esac
