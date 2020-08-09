#!/bin/bash

MYSQL_NAME="{{ mysql_name }}"
MYSQL_CONFIG="{{ mysql_config }}"

MYSQLDUMP_SUF="$(echo ${@:-all} | sed -re 's/[ -]+/./g;s/[=0-9]+//')"
MYSQLDUMP_OPT="${@:--A --master-data=1}"

RUNNING=`mysqladmin --defaults-file=$MYSQL_CONFIG ping 2>/dev/null | grep alive | wc -l`

BACKUP_PATH="{{ backup_path }}"
BACKUP_PARALLEL="{{ backup_parallel }}"

echo
date +"[%F %T] Mysqldump instance '${MYSQL_NAME}'" 

if [ $RUNNING -eq 1 ] ; then 

  date +"[%F %T] Creating dump for mysql-multi instance '${MYSQL_NAME}'..."

  install -d ${BACKUP_PATH}/${MYSQL_NAME}
  
  DUMP_FILE=${BACKUP_PATH}/${MYSQL_NAME}/db-${MYSQL_NAME}.`date +%F`.${MYSQLDUMP_SUF}.sql.gz

  mysqldump --defaults-file=${MYSQL_CONFIG} ${MYSQLDUMP_OPT} | pigz --processes ${BACKUP_PARALLEL} > ${DUMP_FILE} 

  SIZE=`du -m "${DUMP_FILE}" | cut -f1`

  date +"[%F %T] Done: ${DUMP_FILE} (${SIZE} Mb)"

else
  date +"[%F %T] Server is not running" 
  exit 1
fi
