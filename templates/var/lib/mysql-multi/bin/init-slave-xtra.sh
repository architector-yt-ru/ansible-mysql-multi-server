#!/bin/bash

MYSQL_NAME="{{ mysql_name }}"
MYSQL_CONFIG="{{ mysql_config }}"
MYSQL_XTRA_HOST="{{ mysql_master_host | default('') }}"
MYSQL_XTRA_PORT="{{ mysql_xtra_port | default('33301') }}"
MYSQL_REMOTE_CONFIG="${MYSQL_CONFIG}"
BACKUP_PATH=/tmp/${MYSQL_NAME}
FLUSH_DATA=false

# Command options
OPTS=`getopt -o Ih:x:b:er:Ft:B: --long help,host:,xtra-port:,backup-path:,execute,remote-config:,flush,tables:,databases: -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "${OPTS}"

while true; do
  case "$1" in
    -I | --help )           HELP=true; shift ;;
    -e | --execute )        EXECUTE=true; shift ;;
    -F | --flush )          FLUSH_DATA=true; shift ;;
    -h | --host )           MYSQL_XTRA_HOST="$2"; shift 2 ;;
    -x | --xtra-port )      MYSQL_XTRA_PORT="$2"; shift 2 ;;
    -b | --backup-path )    BACKUP_PATH="$2"; shift 2 ;;
    -r | --remote-config )  MYSQL_REMOTE_CONFIG="$2"; shift 2 ;;
    -B | --databases )      MYSQL_XTRA_DATABASES="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

# set defaults
MYSQL_REMOTE_CONFIG=${MYSQL_REMOTE_CONFIG:-MYSQL_CONFIG}

if [ ${FLUSH_DATA} = true ] ; then
  BACKUP_PATH=/var/lib/mysql-${MYSQL_NAME}
fi
if [ "${BACKUP_PATH}" == "/var/lib/mysql-${MYSQL_NAME}" ] || [ "${BACKUP_PATH}" == "/var/lib/mysql-${MYSQL_NAME}/" ]; then 
  FLUSH_DATA=true
fi

DATABASES_LIST=${BACKUP_PATH}/databases.list

if [ "${HELP}" = true ] || [ -z "${EXECUTE}" ] ; then 

  echo
  echo "Usage: $(basename $0) [OPTIONS] -e"
  echo
  echo "  -I, --help          Display this help and exit."
  echo "  -b, --backup-path name"
  echo "                      Temporary directory"
  echo "  -B, --databases mysql,db,db2,db3"
  echo "                      Databases to import, comma separated."
  echo "  -e, --execute       Execute"
  echo "  -F, --flush         Flush data before sync and write data to data_dir"
  echo "  -h, --host name     Connect to host."
  echo "  -r, --remote-config name"
  echo "                      Remote mysql config."
  echo "  -x, --xtra-port #   Port number to use for remote xtrabackup connection."
  echo 
  echo "Variables (--variable-name value)           Value (after reading options)"
  echo "------------------------------------------- ------------------------------"
  echo "backup-path                                 ${BACKUP_PATH}"
  echo "databases                                   ${MYSQL_XTRA_DATABASES}"
  echo "flush                                       ${FLUSH_DATA}"
  echo "host                                        ${MYSQL_XTRA_HOST}"
  echo "remote-config                               ${MYSQL_REMOTE_CONFIG}"
  echo "xtra-port                                   ${MYSQL_XTRA_PORT}"
  exit 4;
fi

date +"[%F %T] Init slave from ${MYSQL_XTRA_HOST}/${MYSQL_REMOTE_CONFIG}" 
if [ ${FLUSH_DATA} = true ] ; then
  /var/lib/mysql-${MYSQL_NAME}/bin/stop.sh
fi

mkdir -p ${BACKUP_PATH}/data
mkdir -p ${BACKUP_PATH}/innodb
find ${BACKUP_PATH}/data -type f -delete
find ${BACKUP_PATH}/innodb -type f -delete

date +"[%F %T] Get remote xtrabackup ..." 

if [ ${MYSQL_XTRA_DATABASES} ] ; then 

  if [[ $(echo "${MYSQL_XTRA_DATABASES}" | grep -Ec "\bmysql\b") -eq 0 ]]; then
    date +"[%F %T] You can't init mysql-server without 'mysql' database, aborting! Use '-B mysql,db1,db2,...'"
    exit 1
  fi

  echo "${MYSQL_XTRA_DATABASES}" | tr "," "\n" > ${DATABASES_LIST}
  curl "http://${MYSQL_XTRA_HOST}:${MYSQL_XTRA_PORT}/dump-databases?${MYSQL_REMOTE_CONFIG}" --data-binary "@${DATABASES_LIST}" -H "Expect:" | \
    unpigz -c | xbstream -x -C ${BACKUP_PATH}/data
else
  curl "http://${MYSQL_XTRA_HOST}:${MYSQL_XTRA_PORT}/dump?${MYSQL_REMOTE_CONFIG}" | \
    unpigz -c | xbstream -x -C ${BACKUP_PATH}/data
fi

if [[ "${PIPESTATUS[0]}" -eq 0 && -f ${BACKUP_PATH}/data/xtrabackup_slave_info ]] ; then 

  date +"[%F %T] Prepare xtrabackup ..." 
  xtrabackup --prepare --use-memory=2G --target-dir=${BACKUP_PATH}/data 2>&1 >> /var/log/xtrabackup.${MYSQL_NAME}.log

  mv -v ${BACKUP_PATH}/data/ibdata* ${BACKUP_PATH}/data/ib_logfile* ${BACKUP_PATH}/innodb

  if [ ${FLUSH_DATA} = false ] ; then 
    /var/lib/mysql-${MYSQL_NAME}/bin/stop.sh

    date +"[%F %T] Backup current data (/var/lib/mysql-${MYSQL_NAME}/{data,innodb}.old) ..." 
    mv -vf /var/lib/mysql-${MYSQL_NAME}/data /var/lib/mysql-${MYSQL_NAME}/data.old
    mv -vf /var/lib/mysql-${MYSQL_NAME}/innodb /var/lib/mysql-${MYSQL_NAME}/innodb.old

    date +"[%F %T] Moving data ..." 
    mv -v ${BACKUP_PATH}/data /var/lib/mysql-${MYSQL_NAME}/data 
    mv -v ${BACKUP_PATH}/innodb /var/lib/mysql-${MYSQL_NAME}/innodb
  fi

  date +"[%F %T] myisamchk ..." 
  myisamchk -r -q $(find /var/lib/mysql-${MYSQL_NAME}/data/ -name "*.MYD" | sed -e 's/.MYD//' | xargs)

  date +"[%F %T] Remove binary and relay logs ..." 
  find /var/lib/mysql-${MYSQL_NAME}/binlog/ -type f -delete -print
  find /var/lib/mysql-${MYSQL_NAME}/relaylog/ -type f -delete -print

  chown -R mysql:mysql /var/lib/mysql-${MYSQL_NAME}/{data,innodb}

  /var/lib/mysql-${MYSQL_NAME}/bin/start-without-network.sh
  /var/lib/mysql-${MYSQL_NAME}/bin/upgrade.sh

  date +"[%F %T] Setting slave info"
  mysql --defaults-file=${MYSQL_CONFIG} -e "STOP SLAVE; RESET SLAVE; RESET MASTER;"
  mysql --defaults-file=${MYSQL_CONFIG} < /var/lib/mysql-${MYSQL_NAME}/data/xtrabackup_slave_info

  if [ -f ${BACKUP_PATH}/data/xtrabackup_binlog_pos_innodb ]; then 
    MASTER_LOG_FILE=$( cat ${BACKUP_PATH}/data/xtrabackup_binlog_pos_innodb | cut -f1 )
    MASTER_LOG_POS=$( cat ${BACKUP_PATH}/data/xtrabackup_binlog_pos_innodb | cut -f2 )
    /var/lib/mysql-${MYSQL_NAME}/bin/apply-replication.sh -f ${MASTER_LOG_FILE} -p ${MASTER_LOG_POS}
  else
    /var/lib/mysql-${MYSQL_NAME}/bin/apply-replication.sh
  fi 

  /var/lib/mysql-${MYSQL_NAME}/bin/restart.sh

  date +"[%F %T] Removing backups (/var/lib/mysql-${MYSQL_NAME}/{data,innodb}.old) ..." 
  rm -rf /var/lib/mysql-${MYSQL_NAME}/data.old
  rm -rf /var/lib/mysql-${MYSQL_NAME}/innodb.old

  date +"[%F %T] Done $0"
  exit 0

else

  date +"[%F %T] Xtrabackup transfer failed, aborting!"
  exit 1
fi


