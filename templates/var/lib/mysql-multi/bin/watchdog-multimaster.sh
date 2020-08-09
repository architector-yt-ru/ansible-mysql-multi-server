#!/bin/bash

MYSQL_CONFIG="{{ mysql_config }}"
MYSQL_SOCKET=`my_print_defaults --defaults-file=$MYSQL_CONFIG mysqld | grep ".sock" | sed -e 's/^.*=//'`
MYSQL_READ_ONLY=`mysql --defaults-file=$MYSQL_CONFIG -e "SELECT @@global.read_only" -N`
MYSQL_SERVER_ID=`mysql --defaults-file=$MYSQL_CONFIG -e "SELECT @@server_id" -N`

[ -S $MYSQL_SOCKET ] || exit 1

for a in {1..6}; do

  REMOTE_SERVER_ID=`mysql --defaults-file=$MYSQL_CONFIG --defaults-group-suffix=_multimaster -e "SELECT @@server_id" -N`

  # Удаленный сервер работает (задан server_id) и удаленный сервер это не локальный
  if [ $REMOTE_SERVER_ID ] && [ "$REMOTE_SERVER_ID" -ne "$MYSQL_SERVER_ID" ] ; then
    
    if [ "$MYSQL_READ_ONLY" -ne 1 ]; then
        mysql --defaults-file=$MYSQL_CONFIG -e "SET GLOBAL read_only=1"
        MYSQL_READ_ONLY=1
        date +"[%F %X] Remote server up, set read_only = 1"
    fi

  else

    if [ "$MYSQL_READ_ONLY" -ne 0 ]; then
        mysql --defaults-file=$MYSQL_CONFIG -e "SET GLOBAL read_only=0"
        MYSQL_READ_ONLY=0
        date +"[%F %X] Remote server down, set read_only = 0"
    fi

  fi

  sleep 9

done

exit 0
