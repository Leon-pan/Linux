#!/bin/sh
date
basepath=$(cd `dirname $0`; pwd)
echo $basepath
filepath=$basepath/hl_metadata_1.0_9050/webapps/hlmd/WEB-INF/classes

set -e

#初始化es命令
inites() {
curl -X PUT "$esip:9200/hl_metadata" -H 'Content-Type: application/json' -d'
{
  "settings": {
    "index": {
      "number_of_shards": "8",
      "number_of_replicas": "1"
    },
	"analysis": {
      "analyzer": {
        "caseSensitive": {
          "filter": "lowercase",
          "type": "custom",
          "tokenizer": "keyword"
        },
        "myAnalyzer": {
           "type":      "pattern",
           "pattern":   "\\W|_",
           "lowercase": true
         },
         "my_custom_analyzer": {
           "type":      "custom",
           "tokenizer": "standard",
           "char_filter": [
             "html_strip"
           ],
           "filter": [
             "lowercase",
             "asciifolding"
           ]
         }
      }
    }
  },
  "mappings": {
    "metadata": {
      "properties": {
          "contextNamePath": {
            "type": "string",
            "analyzer": "ik",
            "search_analyzer": "ik_max_word"
          },
          "createDate": {
            "type": "date",
            "format": "strict_date_optional_time||epoch_millis",
            "locale": "zh_CN"
          },
          "deadTime": {
            "type": "date",
            "format": "strict_date_optional_time||epoch_millis",
            "locale": "zh_CN"
          },
          "effectTime": {
            "type": "date",
            "format": "strict_date_optional_time||epoch_millis",
            "locale": "zh_CN"
          },
          "metadataCode": {
            "type": "string",
            "index": "not_analyzed"
          },
          "metadataDesc": {
            "type": "string",
            "index": "not_analyzed"
          },
          "metadataName": {
            "type": "string",
            "index": "not_analyzed"
          },
          "contextPath": {
             "type": "string",
             "include_in_all": false,
             "index": "not_analyzed"
          },
          "updateDate": {
            "type": "date",
            "format": "strict_date_optional_time||epoch_millis",
            "locale": "zh_CN"
          }
      }
    }
  }
}
' > /dev/null 2>&1
}

#备份
##hlframe.properties
cp -f $filepath/hlframe.properties $filepath/hlframe.properties.`date +%F`
##dist
cp -f $basepath/hl_metadata_1.0_9050/webapps/dist/static/ipaddress.js $basepath/hl_metadata_1.0_9050/webapps/dist/static/ipaddress.js.`date +%F`

#读取stdin
read -p "[1/6]数据库地址是什么？" mysql
#修改为stdin
sed -i 's/${数据库IP}/'"$mysql"/ $filepath/hlframe.properties

read -p "[2/6]hl_metadata对应的数据库密码是什么？" mysqlpasswd
sed -i 's/${用户密码}/'"$mysqlpasswd"/ $filepath/hlframe.properties

read -p "[3/6]当前系统的IP是什么？" ip
sed -i 's/${元数据系统ip}/'"$ip"/ $filepath/hlframe.properties
sed -i 's/${元数据系统ip}/'"$ip"/ $basepath/hl_metadata_1.0_9050/webapps/dist/static/ipaddress.js

#ext_config.properties
cp -f $filepath/ext_config.properties $filepath/ext_config.properties.`date +%F`

read -p "[4/6]ES的IP是什么？" esip
sed -i 's/${ES服务 IP}/'"$esip"/ $filepath/ext_config.properties
inites

read -p "[5/6]Redis的IP是什么？" redisip
sed -i 's/${Redis 单节点IP}/'"$redisip"/ $filepath/ext_config.properties

read -p "[6/6]Redis的密码是什么？" redispasswd
sed -i 's/${Redis 连接密码}/'"$redispasswd"/ $filepath/ext_config.properties


chmod +x $basepath/hl_metadata_1.0_9050/bin/*.sh