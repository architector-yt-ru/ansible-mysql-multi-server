#!/bin/sh

MYSQL_NAME="{{ mysql_name }}"
MYSQL_CONFIG="{{ mysql_config }}"
PATH=/sbin:/usr/sbin:/bin:/usr/bin

# In case server is taking more to start or stop increase the timeout in defaults file
STARTTIMEOUT=900
STOPTIMEOUT=900
 
# Increase max open files
ulimit -n 102400

verify_server () {
    TIMEOUT=0
    if [ "${1}" = "start" ]; then
        TIMEOUT=${STARTTIMEOUT}
    elif [ "${1}" = "stop" ]; then
        TIMEOUT=${STOPTIMEOUT}
    fi

    COUNT=0
    while [ ${COUNT} -lt ${TIMEOUT} ];
    do
        COUNT=$(( COUNT+1 ))
        echo -n .
        if [ "${1}" = "start" ] && [ "$(get_running ${2})" = 1 ]; then
            if [ -z ${3} ]; then
                echo
            fi
            return 0
        fi
        if [ "${1}" = "stop" ] && [ "$(get_running ${2})" = 0 ]; then
            if [ -z ${3} ]; then
                echo
            fi
            return 0
        fi
        sleep 1
    done
    return 1
}

get_pid_file () {

    # local MYSQL_CONFIG="${MYSQL_CONFIGS_DIR}/${1}.cnf"
    local MYSQL_DATA_DIR=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld | awk -F'=' '/datadir/ {print $2}' || echo "/var/lib/mysql"`
    local MYSQL_PID_FILE=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld_safe | awk -F'=' '/pid-file/ {print $2}'`

    if [ -z "${MYSQL_PID_FILE}" ]; then
        MYSQL_PID_FILE=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld | awk -F'=' '/pid-file/ {print $2}' || echo "${MYSQL_DATA_DIR}/$(hostname).pid"`
    fi

    echo ${MYSQL_PID_FILE}
}

get_running () {

    local MYSQL_PID_FILE=$(get_pid_file ${1})

    if [ -e "${MYSQL_PID_FILE}" ] && [ -d "/proc/$(cat "${MYSQL_PID_FILE}")" ]; then
        echo 1
    else
        echo 0
    fi
}

MYSQL_PID_FILE=$(get_pid_file ${MYSQL_NAME})

date +"[%F %T] Stopping mysql-server '${MYSQL_NAME}' " | tr -d '\n'

{% if ansible_distribution == 'Debian' or ansible_distribution == 'Ubuntu' %}
start-stop-daemon --stop --pidfile ${MYSQL_PID_FILE}
{% else %}
systemctl stop mysql-multi@${MYSQL_NAME}
{% endif %}

verify_server stop ${MYSQL_NAME} no-progress

if [ "$?" -eq 0 ] ; then 
  echo " done"
else 
  echo " fail!"
fi

