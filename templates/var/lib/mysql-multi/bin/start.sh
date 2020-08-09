#!/bin/sh

# 1. process running 
# 2. socket exists

MYSQL_NAME="{{ mysql_name }}"
MYSQL_CONFIG="{{ mysql_config }}"
MYSQL_DATA_DIR=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld | awk -F'=' '/datadir/ {print $2}'`
MYSQL_SOCKET=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld | grep "socket=" | cut -f2 -d=`
MYSQL_PID_FILE=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld | awk -F'=' '/pid-file/ {print $2}'`
MYSQL_BASE_DIR=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld | awk -F'=' '/basedir/ {print $2}'`
MYSQLD_OPTS=$@

# PATH=/sbin:/usr/sbin:/bin:/usr/bin

# In case server is taking more to start or stop increase the timeout in defaults file
STARTTIMEOUT=900
STOPTIMEOUT=900
 
# Increase max open files
ulimit -n 102400
install -o mysql -g mysql -d /var/run/mysqld/

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
        if [ "${1}" = "start" ] && [ "$(get_running)" = 1 ] && [ -S "${MYSQL_SOCKET}" ]; then
            return 0
        fi
        # if [ "${1}" = "start" ] && [ "$(get_running)" = 0 ] && [ ${COUNT} -gt 10 ]; then
        #     return 1
        # fi
        if [ "${1}" = "stop" ] && [ "$(get_running)" = 0 ]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

get_running () {

    if [ -e "${MYSQL_PID_FILE}" ] && [ -d "/proc/$(cat "${MYSQL_PID_FILE}")" ]; then
        echo 1
    else
        echo 0
    fi
}

if [ -z "${MYSQL_BASE_DIR}" ] ; then 
    MYSQL_BASE_DIR='/usr'
fi 


date +"[%F %T] Starting mysql-server '${MYSQL_NAME}' ${MYSQLD_OPTS} " | tr -d '\n'

{% if ansible_service_mgr in 'systemd' %}
systemctl set-environment MYSQLD_OPTS=${MYSQLD_OPTS}
systemctl --no-block start mysql-multi@${MYSQL_NAME}
# We must give mysqld time to start with MYSQLD_OPTS
sleep 1
systemctl unset-environment MYSQLD_OPTS
{% elif ansible_os_family == "Debian" %}
start-stop-daemon --start --chuid mysql --background --quiet --exec ${MYSQL_BASE_DIR}/bin/mysqld_safe -- --defaults-file=${MYSQL_CONFIG} "${MYSQLD_OPTS}"
{% else %}
date +"[%F %T] FAIL: Install systemd!"
exit
{% endif %}

verify_server start

if [ "$?" -eq 0 ] ; then 
  echo " done"
  exit 0
else 
  echo " fail!"
  exit 1
fi
