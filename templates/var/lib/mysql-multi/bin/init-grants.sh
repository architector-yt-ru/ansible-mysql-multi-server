#!/bin/bash

MYSQL_NAME="{{ mysql_name }}"
MYSQL_CONFIG="{{ mysql_config }}"

date +"[%F %T] Init grants"

mysql --defaults-file=$MYSQL_CONFIG < /var/lib/mysql-$MYSQL_NAME/sql/grants.sql
RESULT=$?

date +"[%F %T] Done $0"

exit $RESULT
