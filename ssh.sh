#!/bin/bash

GREEN='\E[1;32m' #绿
RED='\E[1;31m'   #红
RES='\E[0m'

#echo "StrictHostKeyChecking no" > ~/.ssh/config

if [ -z "$1"] || [ -z "$2"]; then
    echo -e "${RED}pleast add hosts file and commond，like ./ssh.sh hosts ls${RES}"
    exit 1
fi

for host in $(cat $1); do
    echo -e "${GREEN}exec '$2' on '$host'${RES}"
    ssh root@$host $2 <<- 'EOF'
exit
EOF
done
echo -e "${GREEN}done!${RES}"
