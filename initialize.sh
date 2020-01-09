#!/bin/bash

# influxdb server info
hostname="127.0.0.1"                     #hostname
hostport="8086"                          #hostport

# startTime
startTime=$(date +%Y-%m-%d_%H:%M:%S)
startTime_s=$(date +%s)
echo "start time : ${startTime}"

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

# set environment variables from .env file
fun_read_env() {
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
        # echo -${key}=${value}-
        eval "${key}=${value}"
    done < "${base_dir}/.env"
    return 0
}

# show parameter
fun_show_param() {
    echo ""
    echo "show parameter"
    echo "INFLUXDB_ADMIN_USER    : ${INFLUXDB_ADMIN_USER}"
    echo "INFLUXDB_ADMIN_PASS    : ***"
    echo "INFLUXDB_DB            : ${INFLUXDB_DB}"
    echo "INFLUXDB_DB_POLICIES   : ${INFLUXDB_DB_POLICIES}"
    echo "INFLUXDB_DB_ALL_USER   : ${INFLUXDB_DB_ALL_USER}"
    echo "INFLUXDB_DB_ALL_PASS   : ***"
    echo "INFLUXDB_DB_READ_USER  : ${INFLUXDB_DB_READ_USER}"
    echo "INFLUXDB_DB_READ_PASS  : ***"
    echo "INFLUXDB_DB_WRITE_USER : ${INFLUXDB_DB_WRITE_USER}"
    echo "INFLUXDB_DB_WRITE_PASS : ***"
    return 0
}

# policies string to array
fun_convert_policies() {
    OLD_IFS="$IFS"
    IFS=","
    policies=(${INFLUXDB_DB_POLICIES})
    IFS="$OLD_IFS"
    return 0
}

# execute initialization command
fun_execute_command() {
    set +e
    result=
    echo ""
    echo "check the influxdb is ready"
    for ((t=30;t>0;t--)); do
        result=$(curl -o /dev/null -s -w %{http_code} "http://${hostname}:${hostport}/metrics")
        if [ "x${result}" == "x200" ]; then
            break
        fi
        echo "influxdb is not ready, http_code : [${result}], retry count [${t}]..."
        sleep 1
    done

    if [ "x${result}" == "x200" ]; then
        echo "influxdb is ready..."
        # create database
        echo ""
        echo "create database : ${INFLUXDB_DB}"
        SQL_CREATE_DATABASE="CREATE DATABASE ${INFLUXDB_DB}"
        curl -i -X POST http://${hostname}:${hostport}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_CREATE_DATABASE}"
        # create retention policies
        echo ""
        echo "create retention policies : ${INFLUXDB_DB_POLICIES}"
        for policy in ${policies[@]}; do
            echo "policy : ${policy}";
            SQL_CREATE_POLICIES="CREATE RETENTION POLICY \"${policy}\" ON ${INFLUXDB_DB} DURATION ${policy} REPLICATION 1";
            curl -i -X POST http://${hostname}:${hostport}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_CREATE_POLICIES}";
        done
        # create user and grant privileges
        echo ""
        echo "create user and grant privileges : ${INFLUXDB_DB_ALL_USER}, ${INFLUXDB_DB_READ_USER}, ${INFLUXDB_DB_WRITE_USER}"
        SQL_CREATE_ALL_USER="CREATE USER ${INFLUXDB_DB_ALL_USER} WITH PASSWORD '${INFLUXDB_DB_ALL_PASS}'"
        SQL_CREATE_READ_USER="CREATE USER ${INFLUXDB_DB_READ_USER} WITH PASSWORD '${INFLUXDB_DB_READ_PASS}'"
        SQL_CREATE_WRITE_USER="CREATE USER ${INFLUXDB_DB_WRITE_USER} WITH PASSWORD '${INFLUXDB_DB_WRITE_PASS}'"
        SQL_GRANT_ALL_PRIVILEGES="GRANT ALL ON ${INFLUXDB_DB} TO ${INFLUXDB_DB_ALL_USER}"
        SQL_GRANT_READ_PRIVILEGES="GRANT READ ON ${INFLUXDB_DB} TO ${INFLUXDB_DB_READ_USER}"
        SQL_GRANT_WRITE_PRIVILEGES="GRANT WRITE ON ${INFLUXDB_DB} TO ${INFLUXDB_DB_WRITE_USER}"
        curl -i -X POST http://${hostname}:${hostport}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_CREATE_ALL_USER}"
        curl -i -X POST http://${hostname}:${hostport}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_CREATE_READ_USER}"
        curl -i -X POST http://${hostname}:${hostport}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_CREATE_WRITE_USER}"
        curl -i -X POST http://${hostname}:${hostport}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_GRANT_ALL_PRIVILEGES}"
        curl -i -X POST http://${hostname}:${hostport}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_GRANT_READ_PRIVILEGES}"
        curl -i -X POST http://${hostname}:${hostport}/query --user "${INFLUXDB_ADMIN_USER}:${INFLUXDB_ADMIN_PASS}" --data-urlencode "q=${SQL_GRANT_WRITE_PRIVILEGES}"
    else
        warn "failed to create user successfully because influxdb is not ready"
    fi
    set -e
    return 0
}

# set environment variables from .env file
fun_read_env;
# show parameter
fun_show_param;
# policies string to array
fun_convert_policies;
# execute initialization command
fun_execute_command;

# endTime
endTime=$(date +%Y-%m-%d_%H:%M:%S)
endTime_s=$(date +%s)
sumTime=$((endTime_s - startTime_s))
echo "  end time : ${endTime}"
echo "total time : $sumTime seconds"
echo ""

exit $?
