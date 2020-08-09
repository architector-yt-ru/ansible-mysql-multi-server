#!/bin/bash

MYSQL_NAME="{{ mysql_name }}"
MYSQL_CONFIG="{{ mysql_config }}"

CONFIG_MYSQLD=`my_print_defaults --defaults-file=$MYSQL_CONFIG mysqld`

RUNNING=`mysqladmin --defaults-file=$MYSQL_CONFIG ping 2>/dev/null | grep alive | wc -l`

BACKUP_PATH="$1"
BACKUP_MYSQL_NAME="$2"
BACKUP_PARALLEL="{{ backup_parallel }}"

if [ "$#" -ne 1 ] ; then

  echo "
  Usage: 
    $0 <BACKUP_PATH> [BACKUP_MYSQL_NAME]

        BACKUP_PATH             - path to backup
        BACKUP_MYSQL_NAME       - new mysql instance name

  "
  exit 1

fi

echo
date +"[%F %T] Xtrabackup instance '${MYSQL_NAME}'" 

mkdir -p ${BACKUP_PATH}/data
mkdir -p ${BACKUP_PATH}/innodb

if [ $RUNNING -eq 1 ] ; then 

    ulimit -n 512000

    date +"[%F %T] Backup step ..." 
    # --compact
    xtrabackup --defaults-file=${MYSQL_CONFIG} --parallel=${BACKUP_PARALLEL} --slave-info --backup --target-dir=${BACKUP_PATH}/data

    date +"[%F %T] Prepare step ..." 
    xtrabackup --prepare --use-memory=2G --target-dir=${BACKUP_PATH}/data

    mv -v ${BACKUP_PATH}/data/ibdata* ${BACKUP_PATH}/data/ib_logfile* ${BACKUP_PATH}/innodb

else
    date +"[%F %T] Server is not running" 
    exit 1
fi

