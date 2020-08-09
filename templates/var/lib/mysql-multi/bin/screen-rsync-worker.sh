#!/bin/bash

# RSYNC_SOURCE="rsync://backup-01-fol.prod.vertis.yandex.net:{{ mysql_ss_rsync_port }}/snapshots-mysql-{{ mysql_name }}/"
RSYNC_SOURCE_HOSTS="{{ groups['vertis_prod_backup'] | default([]) | join(' ') }}"
RSYNC_SOURCE_PORT="{{ mysql_ss_rsync_port }}"
MYSQL_NAME="{{ mysql_name }}"
MYSQL_CONFIG="{{ mysql_config }}"
MYSQL_MASTER_HOST="{{ mysql_master_host }}"
MYSQL_MASTER_PORT="{{ mysql_master_port }}"
MYSQL_MASTER_USER="{{ mysql_master_user }}"
MYSQL_MASTER_PASS="{{ mysql_master_pass }}"
MYSQL_SOCKET=`my_print_defaults --defaults-file=$MYSQL_CONFIG mysqld | grep ".sock" | sed -e 's/^.*=//'`
MYSQL_PID=`my_print_defaults --defaults-file=$MYSQL_CONFIG mysqld | grep ".pid" | sed -e 's/^.*=//'`
FORCETIMEOUT=60

echo
date +"[%F %X] Initializing mysql slave" 

if [ -f $MYSQL_PID ] ; then

    date +"[%F %X] Close instance for new connections" 

    /var/lib/mysql-$MYSQL_NAME/bin/server-lock.sh

    date +"[%F %X] Waiting for 20 seconds" 

    sleep 20

    date +"[%F %X] Stopping mysql instance '$MYSQL_NAME'"
    _pid=$(head -n 1 $MYSQL_PID)

    while $(kill -0 ${_pid} 2>/dev/null)
    do
        kill ${_pid}
        sleep 1
    done
fi

date +"[%F %X] Removing binlogs, relaylogs & innodb-files"

rm /var/lib/mysql-$MYSQL_NAME/relaylog/*
rm /var/lib/mysql-$MYSQL_NAME/binlog/*
rm -rf /var/lib/mysql-$MYSQL_NAME/data
rm -rf /var/lib/mysql-$MYSQL_NAME/innodb

date +"[%F %X] Rsync data (excl: bin/ binlog/ sql/)"

for RSYNC_HOST in `echo "$RSYNC_SOURCE_HOSTS" | tr ' ' '\n'| sort -R`
do    
    if nc -w 2 -z $RSYNC_HOST $RSYNC_SOURCE_PORT; then
        date +"[%F %X] Rsync host: $RSYNC_HOST:$RSYNC_SOURCE_PORT"
        rsync --exclude bin --exclude binlog --exclude sql -vrpW --delete "rsync://$RSYNC_HOST:$RSYNC_SOURCE_PORT/snapshots-mysql-$MYSQL_NAME/" /var/lib/mysql-$MYSQL_NAME/
        break;
    else
        date +"[%F %X] Rsync host failed: $RSYNC_HOST:$RSYNC_SOURCE_PORT"
    fi
done

date +"[%F %X] Chown mysql:mysql '/var/lib/mysql-$MYSQL_NAME/'"

chown -R mysql:mysql /var/lib/mysql-$MYSQL_NAME/

if [ -f /var/lib/mysql-$MYSQL_NAME/data/auto.cnf ] ; then
    date +"[%F %X] Reseting UUID"
    rm /var/lib/mysql-$MYSQL_NAME/data/auto.cnf
fi

date +"[%F %X] Starting mysql instance '$MYSQL_NAME' without networking "

start-stop-daemon --start --chuid mysql --background --quiet --exec /usr/bin/mysqld_safe -- --defaults-file=$MYSQL_CONFIG --skip-networking --skip-slave-start

date +"[%F %X] Waiting for socket ($MYSQL_SOCKET) ... "

_timeout=0

while [ ! -S $MYSQL_SOCKET ]
do
    _timeout=$((${_timeout}+1))
    if [ ${_timeout} -gt $FORCETIMEOUT ] ; then
        date +"[%F %X] Failed"
        exit 1
    fi
    sleep 1
done

sleep 10

date +"[%F %X] Preparing slave "

{% if mysql_gtid %}
mysql --defaults-file=$MYSQL_CONFIG -e "STOP SLAVE; RESET SLAVE; CHANGE MASTER TO MASTER_HOST='$MYSQL_MASTER_HOST', MASTER_PORT=$MYSQL_MASTER_PORT, MASTER_USER='$MYSQL_MASTER_USER', MASTER_PASSWORD='$MYSQL_MASTER_PASS', MASTER_AUTO_POSITION=1; START SLAVE;"
{% endif %}

/var/lib/mysql-$MYSQL_NAME/bin/init-grants.sh

date +"[%F %X] Waiting for slave lag"

/var/lib/mysql-$MYSQL_NAME/bin/init-slave-postinstall.sh

date +"[%F %X] Rsync done"


