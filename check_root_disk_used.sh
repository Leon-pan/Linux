#/bin/bash

info() {
    local info="$1"
    local cmd="echo -e $info"
    echo ""
    eval $cmd
    echo ""
}
run_cmd() {
    local cmd="$1"
    local silent=$2

    [ "$silent" != "" ] && cmd+=" > /dev/null 2>&1"
    eval $cmd
}
lsof_user() {
    local user=$1
    lsof -u $user 2>/dev/null | awk '/deleted/{print $7/1024/1024/1024"GB","command:"$1,"file_name:"$9,"PID:"$2,"(deleted)"}' | sort -rnu | grep "^[1-9]." | grep -v "^[0-9]*.*e-"
}
check_root_disk_used() {
    #step1: mount root parttion
    local root_disk=$(df --output=source / | sed -n '$p')
    local temp_dir="/var/check$(date "+%Y-%m-%d")"
    local mounted=0
    run_cmd "mkdir $temp_dir" "slient"
    run_cmd "mount $root_disk $temp_dir"

    if [ $? -eq 0 ]; then
        #step2: scan GB directory
        run_cmd "cd $temp_dir" "slient"
        local du_lines=$(du -shx * .[a-zA-Z0-9_]* 2>/dev/null | egrep '^ *[0-9.]*G' | sort -n | awk '{print $2}')
        info "The following directories could be cleaned up"
        while read d; do
            [ -d $temp_dir/$d ] && run_cmd "cd $temp_dir/$d" || run_cmd "du -shx /$d"
            du -shx * .[a-zA-Z0-9_]* 2>/dev/null | egrep '^ *[0-9.]*G' | sort -n | awk '{print $1, "'''/$d'''/"$2}'
        done <<<"$du_lines"

        #clean temp dir
        run_cmd "cd /var/;umount $temp_dir"
    fi
    [ $(ls -al $temp_dir | wc -l) -eq 3 ] && run_cmd "rm -rf $temp_dir" "silent"

    #step3: scan lsof(deleted)
    info "Scan lsof with deleted, time:$(date "+%Y-%m-%d-%H:%M:%S")"
    local users=$(ps -uax | awk '{print $1}' | sort -n | uniq)
    while read user; do
        [[ "$user" != "USER" ]] && lsof_user $user
    done <<<"$users"
    exit 0
}

check_root_disk_used
