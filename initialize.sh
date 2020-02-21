#!/bin/bash

##########################################################################
# influxdb-initialize.sh
# for centos 7.x
# author : yong.ran@cdjdgm.com
##########################################################################

# local variable
policies=()
step=1

set -e
set -o noglob

# set author info
date1=`date "+%Y-%m-%d %H:%M:%S"`
date2=`date "+%Y%m%d%H%M%S"`
author="yong.ran@cdjdgm.com"

# font and color 
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
white=$(tput setaf 7)

# header and logging
header() { printf "\n${underline}${bold}${blue}> %s${reset}\n" "$@"; }
header2() { printf "\n${underline}${bold}${blue}>> %s${reset}\n" "$@"; }
info() { printf "${white}➜ %s${reset}\n" "$@"; }
warn() { printf "${yellow}➜ %s${reset}\n" "$@"; }
error() { printf "${red}✖ %s${reset}\n" "$@"; }
success() { printf "${green}✔ %s${reset}\n" "$@"; }
usage() { printf "\n${underline}${bold}${blue}Usage:${reset} ${blue}%s${reset}\n" "$@"; }

trap "error '******* ERROR: Something went wrong.*******'; exit 1" sigterm
trap "error '******* Caught sigint signal. Stopping...*******'; exit 2" sigint

set +o noglob

# entry base dir
base_name=`basename $0 .sh`
pwd=`pwd`
base_dir="${pwd}"
source="$0"
while [ -h "$source" ]; do
    base_dir="$( cd -P "$( dirname "$source" )" && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$base_dir/$source"
done
base_dir="$( cd -P "$( dirname "$source" )" && pwd )"
cd "${base_dir}"

# args flag
arg_help=
arg_init=
arg_empty=true

# 解析参数
# echo $@
# 定义选项， -o 表示短选项 -a 表示支持长选项的简单模式(以 - 开头) -l 表示长选项 
# a 后没有冒号，表示没有参数
# b 后跟一个冒号，表示有一个必要参数
# c 后跟两个冒号，表示有一个可选参数(可选参数必须紧贴选项)
# -n 出错时的信息
# -- 也是一个选项，比如 要创建一个名字为 -f 的目录，会使用 mkdir -- -f ,
#    在这里用做表示最后一个选项(用以判定 while 的结束)
# $@ 从命令行取出参数列表(不能用用 $* 代替，因为 $* 将所有的参数解释成一个字符串
#                         而 $@ 是一个参数数组)
# args=`getopt -o ab:c:: -a -l apple,banana:,cherry:: -n "${source}" -- "$@"`
args=`getopt -o h -a -l help,init -n "${source}" -- "$@"`
# 判定 getopt 的执行时候有错，错误信息输出到 STDERR
if [ $? != 0 ]; then
    error "Terminating..." >&2
    exit 1
fi
# echo ${args}
# 重新排列参数的顺序
# 使用eval 的目的是为了防止参数中有shell命令，被错误的扩展。
eval set -- "${args}"
# 处理具体的选项
while true
do
    case "$1" in
        -h | --help | -help)
            info "option -h|--help"
            arg_help=true
            arg_empty=false
            shift
            ;;
        --init | -init)
            info "option --init"
            arg_init=true
            arg_empty=false
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            error "Internal error!"
            exit 1
            ;;
    esac
done
#显示除选项外的参数(不包含选项的参数都会排到最后)
# arg 是 getopt 内置的变量 , 里面的值，就是处理过之后的 $@(命令行传入的参数)
for arg do
   warn "$arg";
done

# define usage
usage=$"`basename $0` [-h|--help] [--init]
       [-h|--help]
                       show help info.
       [--init]
                       execute initialization command.
"

# show usage
fun_show_usage() {
    usage "$usage";
    exit 1
}

# read environment variables from .env file
fun_read_envfile() {
    header "[Step ${step}]: read environment variables from ${base_name}.env file."; let step+=1
    while read line;
    do
        # echo ${line};
        trim=$(echo ${line} | sed 's/^[ ]*//g' | sed 's/[ ]*$//g')
        if [ "x$trim" == "x" ]; then
            # ignore empty line
            continue;
        fi
        rem=$(echo ${trim:0:1})
        if [ "x$rem" == "x#" ]; then
            # ignore rem line
            continue;
        fi
        key=$(echo ${trim%%=*} | sed 's/^[ ]*//g' | sed 's/[ ]*$//g')
        value=$(echo ${trim#*=} | sed 's/^[ ]*//g' | sed 's/[ ]*$//g')
        last=$(echo ${key##*_})
        if [ "x$last" == "xPASS" ]; then
            info "${key}=***"
        else
            info "${key}=${value}"
        fi
        eval "${key}=${value}"
    done < "${base_dir}/${base_name}.env"
    success "successfully readed environment variables."
    return 0
}


fun_convert_policies() {
    OLD_IFS="$IFS"
    IFS=","
    policies=(${INFLUXDB_DB_POLICIES})
    IFS="$OLD_IFS"
    return 0
}

# execute command
fun_execute_command() {
    header "[Step ${step}]: execute initialization command."; let step+=1
    set +e
    echo ""
    info "check if the influxdb[${INFLUXDB_HOST}:${INFLUXDB_PORT}] is ready"
    result=
    for ((t=30;t>0;t--)); do
        result=$(curl -o /dev/null -s -w %{http_code} "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/metrics")
        if [ "x${result}" == "x200" ]; then
            break
        fi
        warn "influxdb[${INFLUXDB_HOST}:${INFLUXDB_PORT}] is not ready, http_code : [${result}], retry count [${t}]..."
        sleep 1
    done
    if [ "x${result}" == "x200" ]; then
        success "influxdb[${INFLUXDB_HOST}:${INFLUXDB_PORT}] is ready..."
        # create database
        echo ""
        info "create database : ${INFLUXDB_DB}"
        SQL_CREATE_DATABASE="CREATE DATABASE ${INFLUXDB_DB}"
        curl -i -X POST http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_CREATE_DATABASE}"
        success "successfully created database."
        # convert policies string to array
        OLD_IFS="$IFS" && IFS="," && policies=(${INFLUXDB_DB_POLICIES}) && IFS="$OLD_IFS"
        # create retention policies
        echo ""
        info "create retention policies : ${INFLUXDB_DB_POLICIES}"
        for policy in ${policies[@]}; do
            echo ""
            info "policy : ${policy}";
            SQL_CREATE_POLICIES="CREATE RETENTION POLICY \"${policy}\" ON ${INFLUXDB_DB} DURATION ${policy} REPLICATION 1";
            curl -i -X POST http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_CREATE_POLICIES}";
        done
        success "successfully created policys."
        # create user and grant privileges
        SQL_CREATE_ALL_USER="CREATE USER ${INFLUXDB_DB_ALL_USER} WITH PASSWORD '${INFLUXDB_DB_ALL_PASS}'"
        SQL_CREATE_READ_USER="CREATE USER ${INFLUXDB_DB_READ_USER} WITH PASSWORD '${INFLUXDB_DB_READ_PASS}'"
        SQL_CREATE_WRITE_USER="CREATE USER ${INFLUXDB_DB_WRITE_USER} WITH PASSWORD '${INFLUXDB_DB_WRITE_PASS}'"
        SQL_GRANT_ALL_PRIVILEGES="GRANT ALL ON ${INFLUXDB_DB} TO ${INFLUXDB_DB_ALL_USER}"
        SQL_GRANT_READ_PRIVILEGES="GRANT READ ON ${INFLUXDB_DB} TO ${INFLUXDB_DB_READ_USER}"
        SQL_GRANT_WRITE_PRIVILEGES="GRANT WRITE ON ${INFLUXDB_DB} TO ${INFLUXDB_DB_WRITE_USER}"
        echo ""
        info "create user : ${INFLUXDB_DB_ALL_USER}"
        curl -i -X POST http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_CREATE_ALL_USER}"
        echo ""
        info "grant privileges : ${INFLUXDB_DB_ALL_USER}"
        curl -i -X POST http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_GRANT_ALL_PRIVILEGES}"
        echo ""
        info "create user : ${INFLUXDB_DB_READ_USER}"
        curl -i -X POST http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_CREATE_READ_USER}"
        echo ""
        info "grant privileges : ${INFLUXDB_DB_READ_USER}"
        curl -i -X POST http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_GRANT_READ_PRIVILEGES}"
        echo ""
        info "create user : ${INFLUXDB_DB_WRITE_USER}"
        curl -i -X POST http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_CREATE_WRITE_USER}"
        echo ""
        info "grant privileges : ${INFLUXDB_DB_WRITE_USER}"
        curl -i -X POST http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_GRANT_WRITE_PRIVILEGES}"
        success "successfully created user and grant privileges."
        success "successfully executed initialization command."
    else
        warn "failed to create database policy and user, because influxdb[${INFLUXDB_HOST}:${INFLUXDB_PORT}] is not ready in 30 seconds."
    fi
    set -e
    return 0
}

##########################################################################

# argument is empty
if [ "x${arg_empty}" == "xtrue" ]; then
    # show usage
    fun_show_usage
fi

# show usage
if [ "x${arg_help}" == "xtrue" ]; then
    # show usage
    fun_show_usage
fi

# init
if [ "x${arg_init}" == "xtrue" ]; then
    # show startTime
    startTime=$(date +%Y-%m-%d_%H:%M:%S)
    startTime_s=$(date +%s)
    info "start time : ${startTime}"
    # read environment variables from .env file
    fun_read_envfile;
    # execute command
    fun_execute_command;
    echo ""
    # show endTime
    endTime=$(date +%Y-%m-%d_%H:%M:%S)
    endTime_s=$(date +%s)
    sumTime=$((endTime_s - startTime_s))
    info "  end time : ${endTime}"
    info "total time : $sumTime seconds"
fi

echo ""

exit $?
