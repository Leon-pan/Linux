#!/bin/bash
read -p "请输入单号:" id

#json=$(curl xxx)
json=$(cat test.json)
#依赖jq命令
status=$(echo $json | jq -r .status)
planPublishDate=$(echo $json | jq -r .planPublishDate)
publishTime=$(echo $json | jq -r .publishTime)
planTimestamp=$(date -d "$planPublishDate $publishTime" +%s)
now=$(date +%s)
if [ $now -gt $planTimestamp ]; then
    echo OK
else
    echo NOT OK
fi
