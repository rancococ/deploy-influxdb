#!/usr/bin/env bash

##########################################################################
# compose-helper.sh
# --setup   : 注册容器
# --start   : 启动容器
# --stop    : 停止容器
# --down    : 卸载容器
# --list    : 查看容器
##########################################################################

# set -x
set -e
set -o noglob

##########################################################################
# set author info
date1=`date "+%Y-%m-%d %H:%M:%S"`
date2=`date "+%Y%m%d%H%M%S"`
author="yong.ran@cdjdgm.com"

##########################################################################
# set font and color 
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
white=$(tput setaf 7)

##########################################################################
# header and logging
header() { printf "\n${underline}${bold}${blue}► %s${reset}\n" "$@"; }
header2() { printf "\n${underline}${bold}${blue}♦ %s${reset}\n" "$@"; }
info() { printf "${white}➜ %s${reset}\n" "$@"; }
info2() { printf "${red}➜ %s${reset}\n" "$@"; }
warn() { printf "${yellow}➜ %s${reset}\n" "$@"; }
error() { printf "${red}✖ %s${reset}\n" "$@"; }
success() { printf "${green}✔ %s${reset}\n" "$@"; }
usage() { printf "\n${underline}${bold}${blue}Usage:${reset} ${blue}%s${reset}\n" "$@"; }

trap "error '******* ERROR: Something went wrong.*******'; exit 1" sigterm
trap "error '******* Caught sigint signal. Stopping...*******'; exit 2" sigint

set +o noglob

##########################################################################
# entry base dir
pwd=`pwd`
base_dir="${pwd}"
source="$0"
while [ -h "$source" ]; do
    base_dir="$( cd -P "$( dirname "$source" )" && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$base_dir/$source"
done
base_dir="$( cd -P "$( dirname "$source" )" && pwd )"
cd ${base_dir}

##########################################################################
# envirionment
self_name=`basename $0  .sh`
compose_bin=/usr/local/bin/docker-compose
compose_yml=${base_dir}/${self_name}.yml
project_dir=${base_dir}
project_name=${self_name}

# init args flag
arg_help=
arg_setup=
arg_start=
arg_stop=
arg_down=
arg_list=
arg_empty=true

##########################################################################
# parse parameter
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
args=`getopt -o h -a -l help,setup,start,stop,down,list -n "${source}" -- "$@"`
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
        --setup | -setup)
            info "option --setup"
            arg_setup=true
            arg_empty=false
            shift
            ;;
        --start | -start)
            info "option --start"
            arg_start=true
            arg_empty=false
            shift
            ;;
        --stop | -stop)
            info "option --stop"
            arg_stop=true
            arg_empty=false
            shift
            ;;
        --down | -down)
            info "option --down"
            arg_down=true
            arg_empty=false
            shift
            ;;
        --list | -list)
            info "option --list"
            arg_list=true
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

# show usage
usage=$"`basename $0` [-h|--help] [--setup] [--start] [--stop] [--down] [--list]
       [-h|--help]          : show help info.
       [--setup]            : docker-compose xxx up -d.
       [--start]            : docker-compose xxx start.
       [--stop]             : docker-compose xxx stop.
       [--down]             : docker-compose xxx down.
       [--list]             : docker-compose xxx list.
"


##########################################################################
# execute docker-compose command
fun_execute_compose_command() {
    command=$1
    header "execute command:[docker-compose --file ${compose_yml} ${command}]"
    info "execute command [docker-compose --file ${compose_yml} ${command}] start."
    ${compose_bin} --file ${compose_yml} --project-name ${project_name} --project-directory ${project_dir} ${command}
    success "execute command [docker-compose --file ${compose_yml} ${command}] end."
    return 0
}


##########################################################################

# argument is empty
if [ "x${arg_empty}" == "xtrue" ]; then
    usage "$usage";
    exit 1
fi

# show usage
if [ "x${arg_help}" == "xtrue" ]; then
    usage "$usage";
    exit 1
fi

# setup
if [ "x${arg_setup}" == "xtrue" ]; then
    fun_execute_compose_command "up -d";
fi

# start
if [ "x${arg_start}" == "xtrue" ]; then
    fun_execute_compose_command "start";
fi

# stop
if [ "x${arg_stop}" == "xtrue" ]; then
    fun_execute_compose_command "stop";
fi

# down
if [ "x${arg_down}" == "xtrue" ]; then
    fun_execute_compose_command "down";
fi

# list
if [ "x${arg_list}" == "xtrue" ]; then
    fun_execute_compose_command "ps";
fi

success "complete."

exit $?
