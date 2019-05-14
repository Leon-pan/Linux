#!/bin/bash
#by pjl
#failover.sh
for host in $(cat /home/failover/ip.txt); do
    ssh $host > /dev/null 2>&1 <<- 'EOF'
sed -i '/^server_host=/c\server_host=10.147.113.12' /etc/cloudera-scm-agent/config.ini
systemctl restart cloudera-scm-agent.service
exit
EOF
done
echo done!
