#!/bin/bash

MYSQL_NAME="{{ mysql_name }}"
MYSQL_CONFIG="{{ mysql_config }}"
MYSQL_MASTER_HOST="{{ mysql_master_host | default('') }}"
MYSQL_MASTER_PORT="{{ mysql_master_port | default('') }}"
MYSQL_MASTER_USER="{{ mysql_master_user | default('') }}"
MYSQL_MASTER_PASS="{{ mysql_master_pass | default('') }}"
MYSQL_SOCKET=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld | grep ".sock" | sed -e 's/^.*=//'`
MYSQL_PID=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld | grep ".pid" | sed -e 's/^.*=//'`
FORCETIMEOUT=60
WAITTIMEOUT=7200
IGNORE_TABLE=""
MYSQLDUMP_DATABASES=""

{% if mysql_replicate_ignore_db or mysql_replicate_ignore_table or mysql_replicate_wild_ignore_table %}
# Ignoring tables
# Not supperted: replicate-do-table, replicate-do-db, replicate-rewrite-db, replicate-wild-do-table
date +"[%F %T] Preparing '--ignore-table' mysqldump parameters ... "

# replicate_ignore_db
{% for item in mysql_replicate_ignore_db|default([]) %}
IGNORE=$(mysql --defaults-file=${MYSQL_CONFIG} --defaults-group-suffix=_replication -N -e 'select concat("--ignore-table=", TABLE_SCHEMA, ".", TABLE_NAME) from information_schema.TABLES where TABLE_SCHEMA="{{item}}"' | xargs)
IGNORE_TABLE="${IGNORE_TABLE} ${IGNORE}"
{% endfor %}

# replicate_ignore_table
{% for item in mysql_replicate_ignore_table|default([]) %}
IGNORE_TABLE="${IGNORE_TABLE} --ignore-table={{item}}"
{% endfor %}

# replicate_wild_ignore_table
{% for item in mysql_replicate_wild_ignore_table|default([]) %}
IGNORE=$(mysql --defaults-file=${MYSQL_CONFIG} --defaults-group-suffix=_replication -N -e 'select concat("--ignore-table=", TABLE_SCHEMA, ".", TABLE_NAME) from information_schema.TABLES where concat(TABLE_SCHEMA, ".", TABLE_NAME) like "{{item}}"' | xargs)
IGNORE_TABLE="${IGNORE_TABLE} ${IGNORE}"
{% endfor %}

{% endif %}

# Command options
OPTS=`getopt -o IB:e --long help,execute,databases: -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "${OPTS}"

while true; do
  case "$1" in
    -I | --help )           HELP=true; shift ;;
    -e | --execute )        EXECUTE=true; shift ;;
    -B | --databases )      MYSQLDUMP_DATABASES="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ "${HELP}" = true ] || [ -z "${EXECUTE}" ] ; then 

  echo
  echo "Usage: $(basename $0) [OPTIONS] -e"
  echo
  echo "  -I, --help          Display this help and exit."
  echo "  -B, --databases mysql,db,db2,db3"
  echo "                      Databases to import, comma separated."
  echo "  -e, --execute       Execute"
  echo 
  echo "Variables (--variable-name value)           Value (after reading options)"
  echo "------------------------------------------- ------------------------------"
  echo "databases                                   ${MYSQLDUMP_DATABASES}"
  exit 4;
fi

/var/lib/mysql-${MYSQL_NAME}/bin/stop.sh
/var/lib/mysql-${MYSQL_NAME}/bin/start-without-network.sh

date +"[%F %T] Waiting for socket ($MYSQL_SOCKET) ... "

_timeout=0

while [ ! -S ${MYSQL_SOCKET} ]
do
  _timeout=$((${_timeout}+1))
  if [ ${_timeout} -gt ${FORCETIMEOUT} ] ; then
    date +"[%F %T] Failed"
    exit 1
  fi
  sleep 1
done

date +"[%F %T] Preparing slave before mysqldump"

mysql --defaults-file=${MYSQL_CONFIG} -e "STOP SLAVE; RESET SLAVE; RESET MASTER; CHANGE MASTER TO MASTER_HOST='$MYSQL_MASTER_HOST', MASTER_PORT=$MYSQL_MASTER_PORT, MASTER_USER='$MYSQL_MASTER_USER', MASTER_PASSWORD='$MYSQL_MASTER_PASS', MASTER_AUTO_POSITION={{ mysql_gtid }};"

if [ "${MYSQLDUMP_DATABASES}" ] ; then
  date +"[%F %T] Mysqldumping [Databases: ${MYSQLDUMP_DATABASES}] ..."
  mysqldump --defaults-file=${MYSQL_CONFIG} --defaults-group-suffix=_init --all-databases=0 -B ${MYSQLDUMP_DATABASES//,/ } | mysql --defaults-file=${MYSQL_CONFIG} --defaults-group-suffix=_init
else
  date +"[%F %T] Mysqldumping ..."
  mysqldump --defaults-file=${MYSQL_CONFIG} --defaults-group-suffix=_init ${IGNORE_TABLE} | mysql --defaults-file=${MYSQL_CONFIG} --defaults-group-suffix=_init
fi

if [ ${PIPESTATUS[0]} ] ; then
  date +"[%F %T] Dump failed, check logs"
  exit 1
fi

# Init grants
/var/lib/mysql-$MYSQL_NAME/bin/init-grants.sh

if mysql --defaults-file=$MYSQL_CONFIG -e 'select @@global.skip_networking' -N | grep 0 ; then
  date +"[%F %X] Mysql-server already run with network. Exit."
  exit 0;
fi

# wait some time before replication really start
sleep 10

while [ -S $MYSQL_SOCKET ]
do
  _timeout=$((${_timeout}+1))
  if [ ${_timeout} -gt $WAITTIMEOUT ] ; then
    date +"[%F %X] Server not ready, timeouted (${WAITTIMEOUT}s)"
    date +"[%F %X] Failed"
    exit 1
  fi
  MYSQL_SLAVE_STATUS=$(mysql --defaults-file=$MYSQL_CONFIG -e 'show slave status\G')
  MYSQL_LAST_ERROR=$(echo ${MYSQL_SLAVE_STATUS} | grep -oP "(?<=Last_Error: )(.*)$")

  if [ ${MYSQL_LAST_ERROR} ] ; then
    date +"[%F %X] Replication is broken. Error: ${MYSQL_LAST_ERROR} ..."
    date +"[%F %X] Failed"
    exit 1
  fi
  if [ $(echo ${MYSQL_SLAVE_STATUS} | grep -cE "(Slave_IO_Running: Yes|Slave_SQL_Running: Yes|Seconds_Behind_Master: 0)" ) -eq 3 ] ; then
    date +"[%F %X] Server ready! Restarting with network ..."
    /var/lib/mysql-${MYSQL_NAME}/bin/restart.sh
    date +"[%F %T] Done $0"
    exit 0        
  fi
  sleep 1
done


