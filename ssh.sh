#!/bin/bash

GREEN='\E[1;32m' #绿
RED='\E[1;31m'   #红
RES='\E[0m'

for host in $(cat $1); do
    echo -e "${GREEN}exec '$2' on '$host'${RES}"
    ssh root@$host $2 <<- 'EOF'
exit
EOF
done
echo -e "${GREEN}done!${RES}"
