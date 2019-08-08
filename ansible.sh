vi /etc/ansible/hosts


#ping测试
ansible windows -m win_ping


#删除文件
ansible windows -m win_file -a "dest=C:\hlTest\hl_bizdemo\\\files\update\incremental\ state=absent"
ansible windows -m win_file -a "dest=C:\hlTest\hl_bizdemo\\\files\update\hl_bizdemo.jar state=absent"

ansible linux -m file -a "path=/tmp/hl_bizdemo/files/update/incremental state=absent"
ansible linux -m file -a "path=/tmp/hl_bizdemo/files/update/hl_bizdemo.jar state=absent"

#上传文件
ansible windows -m win_copy -a "src=/root/update/incremental dest=C:\hlTest\hl_bizdemo\\\files\update"
ansible windows -m win_copy -a "src=/root/update/hl_bizdemo.jar dest=C:\hlTest\hl_bizdemo\\\files\update\hl_bizdemo.jar"

ansible linux -m copy -a "src=/root/update/incremental dest=/tmp/hl_bizdemo/files/update/"
ansible linux -m copy -a "src=/root/update/hl_bizdemo.jar dest=/tmp/hl_bizdemo/files/update/hl_bizdemo.jar"


#执行脚本
ansible windows -m raw -a "C:\hlTest\hl_bizdemo\\\bin\startServer.bat"

ansible linux -m shell -a "/tmp/hl_bizdemo/bin/updateServer.sh"


#字符编码修改
cp /usr/lib/python2.7/site-packages/winrm/protocol.py{,.bak}
sed -i "s#tdout_buffer.append(stdout)#tdout_buffer.append(stdout.decode('gbk').encode('utf-8'))#g" /usr/lib/python2.7/site-packages/winrm/protocol.py
sed -i "s#stderr_buffer.append(stderr)#stderr_buffer.append(stderr.decode('gbk').encode('utf-8'))#g" /usr/lib/python2.7/site-packages/winrm/protocol.py