#!/bin/bash

set -o pipefail

MYSQL_NAME="{{ mysql_name }}"
MYSQL_CONFIG="{{ mysql_config }}"

RUNNING=`mysqladmin --defaults-file=$MYSQL_CONFIG ping 2>/dev/null | grep alive | wc -l`

BACKUP_PATH="{{ backup_path }}"
BACKUP_PARALLEL="{{ backup_parallel }}"

DATE=`date +%F`
SNAPSHOT_FILE="${BACKUP_PATH}/snapshot.mysql-${MYSQL_NAME}.${DATE}.tgz"

echo
date +"[%F %T] Backuping mysql instance '${MYSQL_NAME}'" 

if [ $RUNNING -eq 1 ] ; then 

  /var/lib/mysql-${MYSQL_NAME}/bin/stop.sh

  if [ "$?" -ne 0 ] ; then 
    date +"[%F %T] Failed to stop, aborted!" && exit 1
  fi
fi


date +"[%F %T] Gzipping to ${SNAPSHOT_FILE} ..." 

cp ${MYSQL_CONFIG} /var/lib/mysql-${MYSQL_NAME}/
tar -c -C /var/lib/ -f - mysql-${MYSQL_NAME} | pigz --processes ${BACKUP_PARALLEL} > ${SNAPSHOT_FILE}
RES=$?

/var/lib/mysql-${MYSQL_NAME}/bin/start.sh

if [ "${RES}" -ne 0 ] ; then 
  date +"[%F %T] Failed to create snapshot!" && exit 1
fi

SNAPSHOT_SIZE=`du -ms "${SNAPSHOT_FILE}" | cut -f1 || echo "--"`

date +"[%F %T] Done: '${SNAPSHOT_FILE}' (${SNAPSHOT_SIZE} mb)" 

exit 0
