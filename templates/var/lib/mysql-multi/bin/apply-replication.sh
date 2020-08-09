#!/bin/bash

MYSQL_CONFIG="{{ mysql_config }}"

CONFIG_MYSQLD=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld`
CONFIG_REPLICATION=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysql_replication --show`

# Command options
OPTS=`getopt -o Ief:p: --long help,execute,master_log_file:,master_log_pos: -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "${OPTS}"

while true; do
  case "$1" in
    -I | --help )             HELP=true; shift ;;
    -e | --execute )          EXECUTE=true; shift ;;
    -f | --master_log_file )  MASTER_LOG_FILE="$2"; shift 2 ;;
    -p | --master_log_pos )   MASTER_LOG_POS="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ "${HELP}" = true ] ; then 

  echo
  echo "Usage: $(basename $0) [OPTIONS] -e"
  echo
  echo "  -I, --help          Display this help and exit."
  echo "  -f, --master_log_file file_name"
  echo "                      Master log file"
  echo "  -p, --master_log_pos n "
  echo "                      Master log position"
  echo 
  echo "Variables (--variable-name value)           Value (after reading options)"
  echo "------------------------------------------- ------------------------------"
  echo "master_log_file                             ${MASTER_LOG_FILE}"
  echo "master_log_pos                              ${MASTER_LOG_POS}"
  exit 4;
fi

RUNNING=`mysqladmin --defaults-file=${MYSQL_CONFIG} ping 2>/dev/null | grep alive | wc -l`

echo
date +"[%F %T] Replication configurator" 

if [ ${RUNNING} -eq 1 ] ; then 

  date +"[%F %T] Getting configurations ..." 

  STATUS=`mysql --defaults-file=${MYSQL_CONFIG} -se "show slave status\G" 2>/dev/null`

  RUNNING_AUTO_POSITION=`echo "${STATUS}" | egrep 'Auto_Position' | cut -d\: -f2`
  CONFIG_GTID_MODE=`echo "${CONFIG_MYSQLD}" | egrep 'gtid_mode=' | cut -d= -f2`
  CONFIG_MASTER_HOST=`echo "${CONFIG_REPLICATION}" | egrep 'host=' | cut -d= -f2`
  CONFIG_MASTER_PORT=`echo "${CONFIG_REPLICATION}" | egrep 'port=' | cut -d= -f2`
  CONFIG_MASTER_USER=`echo "${CONFIG_REPLICATION}" | egrep 'user=' | cut -d= -f2`
  CONFIG_MASTER_PASS=`echo "${CONFIG_REPLICATION}" | egrep 'password=' | cut -d= -f2`

  if [ "${CONFIG_GTID_MODE}" != 'on' ]; then 

    if [ ! "${MASTER_LOG_FILE}" ] || [ ! "${MASTER_LOG_POS}" ]; then

      date +"[%F %T] Server running without gtid_mode=on! Check help (--help option)" 
      exit 2

    else

      mysql --defaults-file=${MYSQL_CONFIG} -e "
        STOP SLAVE; 
        RESET SLAVE; 
        CHANGE MASTER TO 
          MASTER_HOST='${CONFIG_MASTER_HOST}', 
          MASTER_PORT=${CONFIG_MASTER_PORT}, 
          MASTER_USER='${CONFIG_MASTER_USER}', 
          MASTER_PASSWORD='${CONFIG_MASTER_PASS}', 
          MASTER_LOG_FILE='${MASTER_LOG_FILE}', 
          MASTER_LOG_POS=${MASTER_LOG_POS}, 
          MASTER_AUTO_POSITION=0; 
        START SLAVE;"

      if [ $? -eq 0 ]; then
        date +"[%F %T] Configuration changed (${CONFIG_MASTER_USER}@${CONFIG_MASTER_HOST}:${CONFIG_MASTER_PORT}/${MASTER_LOG_FILE}:${MASTER_LOG_POS})" 
        exit 0
      else
        date +"[%F %T] Changing failed!" 
        exit 1
      fi 

    fi

  else

    RUNNING_MASTER_HOST=`echo "${STATUS}" | egrep 'Master_Host' | cut -d\: -f2`
    RUNNING_MASTER_PORT=`echo "${STATUS}" | egrep 'Master_Port' | cut -d\: -f2`
    RUNNING_MASTER_USER=`echo "${STATUS}" | egrep 'Master_User' | cut -d\: -f2`

    if [ "${CONFIG_MASTER_HOST}" != "${RUNNING_MASTER_HOST}" ] || 
      [ "${CONFIG_MASTER_PORT}" != "${RUNNING_MASTER_PORT}" ] || 
      [ "${CONFIG_MASTER_USER}" != "${RUNNING_MASTER_USER}" ] ; then 

      mysql --defaults-file=${MYSQL_CONFIG} -e "
        STOP SLAVE; 
        RESET SLAVE; 
        CHANGE MASTER TO 
          MASTER_HOST='${CONFIG_MASTER_HOST}', 
          MASTER_PORT=${CONFIG_MASTER_PORT}, 
          MASTER_USER='${CONFIG_MASTER_USER}', 
          MASTER_PASSWORD='${CONFIG_MASTER_PASS}', 
          MASTER_AUTO_POSITION=1; 
        START SLAVE;"

      if [ $? -eq 0 ]; then
        date +"[%F %T] Configuration changed (${CONFIG_MASTER_USER}@${CONFIG_MASTER_HOST}:${CONFIG_MASTER_PORT})" 
        exit 0
      else
        date +"[%F %T] Changing failed!" 
        exit 1
      fi 

    else
      date +"[%F %T] Everything ok" 
      exit 0
    fi 

  fi # CONFIG_GTID_MODE

else
  date +"[%F %T] Server is not running" 
  exit 1
fi

