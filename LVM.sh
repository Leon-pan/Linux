#创建PV
pvcreate /dev/vdb

#查看PV
pvscan
pvs


#创建VG
vgcreate vgname /dev/vdb

#查看VG
vgs
vgscan
vgdisplay


#创建LV
lvcreate -l 10 -n lvname vgname
lvcreate -L 200M -n lvname vgname

#查看LV
lvscan


#创建文件系统并挂载
mkfs.xfs /dev/vgname/lvname
mkfs.ext4 /dev/vgname/lvname


#VG管理
##扩大VG vgextend
###pv
pvcreate /dev/vdc

###vgentend
vgentend vgname /dev/vdc
vgs

##减小VG vgreduce
##通常先做数据的迁移
###查看当前VG中PV的使用情况
pvs
PV       VG    Fmt  Attr  PSize  PFree
/dev/vdd  vg1  lvm2 a--   2.00g 1.76g
/dev/vde  vg1  lvm2 a--   2.00g 2.00g

###pvmove数据到其他PV
pvmove /dev/vdd

pvs
PV       VG    Fmt  Attr  PSize  PFree
/dev/vdd  vg1  lvm2 a--   2.00g 2.00g
/dev/vde  vg1  lvm2 a--   2.00g 1.76g

###vgreduce VG
vgreduce vgname /dev/vdd


#LV扩容
##LV扩容
vgs

# 格式： lvextend -L +10G lv绝对路径
# 注意要有加号，否则就表示将该lv扩展至10G
lvextend -L 800M /dev/vgname/lvname
lvextend -L +800M /dev/vgname/lvname

lvextend -l 15 /dev/vgname/lvname
lvextend -l +15 /dev/vgname/lvname

lvscan

##FS扩容
###xfs
xfs_growfs /dev/vgname/lvname

###ext2/3/4
resize2fs /dev/vgname/lvname


#LVM缩容
###xfs备份xfsdump -f /home.xfsdump /dev/centos/home
###xfs还原xfsrestore -f /home.xfsdump /home
umount /dev/vgname/lvname

##检测磁盘错误
e2fsck /dev/vgname/lvname

##缩小文件系统，更新信息
resize2fs -f /dev/vgname/lvname 15g

##减少逻辑卷大小
lvreduce -L15g /dev/vgname/lvname










# 格式：pvcreate 物理磁盘目录
pvcreate /dev/sdb
# 查看已创建的物理卷
pvdisplay 


# 格式：vgcreate 卷组名 物理磁盘目录
vgcreate datavg /dev/sdb
# 查看已经创建的卷组
vgdisplay


# 格式： lvcreate -n 逻辑卷名 -L 逻辑卷大小 卷组名
lvcreate -l 100%VG -n data_oracle datavg
# 查看已经创建的逻辑卷
lvdisplay




如果上面的“Free PE / Size”还有空间，并且剩余的空间能满足扩展需求，那么可以直接用lvextend命令

# 格式： lvextend -L +10G lv绝对路径
# 注意要有加号，否则就表示将该lv扩展至10G
lvextend -L +10G lv_path



扩展完成后，还需补充格式化新扩展的卷的文件系统，否则df -hl是看不到扩展的大小的

resize2fs lv_path
那么，如果VG中已经没有剩余空间了，那么就需要追加挂载磁盘，然后重新创建新的PV，然后加到当前的VG中（vgextend），然后才是LV的扩展