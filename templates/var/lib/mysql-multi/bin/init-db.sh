#!/bin/bash

MYSQL_NAME="{{ mysql_name }}"
MYSQL_CONFIG="{{ mysql_config }}"
MYSQL_BASE_DIR=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld | awk -F'=' '/basedir/ {print $2}'`
MYSQL_LOG_ERROR=`my_print_defaults --defaults-file=${MYSQL_CONFIG} mysqld | awk -F'=' '/log-error/ {print $2}'`
MYSQL_MYSQLD="/usr/sbin/mysqld"

if [ "${MYSQL_BASE_DIR}" ] ; then 
    MYSQL_MYSQLD="${MYSQL_BASE_DIR}/bin/mysqld"
fi 

MYSQL_VERSION=`${MYSQL_MYSQLD} --version  | grep -P -o '(?<=Ver )\d\.\d'`

FORCE='false'
while getopts 'f' flag; do
  case "${flag}" in
    f) FORCE='true' ;;
  esac
done

/var/lib/mysql-${MYSQL_NAME}/bin/stop.sh

if [ "${FORCE}" == "true" ] ; then 
  date +"[%F %T] Forcibly removing data directories '${MYSQL_NAME}'"

  rm -rfv /var/lib/mysql-${MYSQL_NAME}/data/*
  rm -rfv /var/lib/mysql-${MYSQL_NAME}/innodb/*

fi

date +"[%F %T] initializing database '${MYSQL_NAME}' by ${MYSQL_MYSQLD} "

case "${MYSQL_VERSION}" in
  '5.6') 

    if [ -x ${MYSQL_BASE_DIR}/bin/mysql_install_db ] ; then
      ${MYSQL_BASE_DIR}/bin/mysql_install_db --defaults-file=${MYSQL_CONFIG}
    elif [ -x ${MYSQL_BASE_DIR}/scripts/mysql_install_db ] ; then
      ${MYSQL_BASE_DIR}/scripts/mysql_install_db --defaults-file=${MYSQL_CONFIG} --basedir=${MYSQL_BASE_DIR}
    fi

    INIT=$?

    if [ "${INIT}" -eq 0 ] ; then 
      date +"[%F %T] Init grants '${MYSQL_NAME}'"
      /var/lib/mysql-${MYSQL_NAME}/bin/start.sh --skip-networking
      mysql --defaults-file=${MYSQL_CONFIG} --password="" < /var/lib/mysql-${MYSQL_NAME}/sql/grants.sql
      /var/lib/mysql-${MYSQL_NAME}/bin/stop.sh
    fi

    ;;
  '5.7'|'8.0') 
    ${MYSQL_MYSQLD} --defaults-file=${MYSQL_CONFIG} --initialize-insecure --innodb_buffer_pool_size=128M --skip-networking --init-file=/var/lib/mysql-${MYSQL_NAME}/sql/grants.sql
    INIT=$?
    ;;

esac

if [ "${INIT}" -eq 0 ] ; then 
  date +"[%F %T] Done $0"
  exit 0
else 
  date +"[%F %T] Failed!"
  echo "Check: ${MYSQL_LOG_ERROR}"
  echo "Data and innodb dirs must be empty!"
  exit 1
fi


exit $?

