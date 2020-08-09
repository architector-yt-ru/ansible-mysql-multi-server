#!/bin/bash

MYSQL_CONFIG="{{ mysql_config }}"

date +"[%F %T] Unlock server"

mysql --defaults-file=$MYSQL_CONFIG -e "SET SQL_LOG_BIN = 0; GRANT USAGE ON *.* TO 'haproxy'@'%'; SET SQL_LOG_BIN = 1;"

date +"[%F %T] Done $0"
