#!/bin/bash

MYSQL_CONFIG="{{ mysql_config }}"

date +"[%F %T] Lock server"

mysql --defaults-file=$MYSQL_CONFIG -e "SET SQL_LOG_BIN = 0; DROP USER haproxy; SET SQL_LOG_BIN = 1;"

date +"[%F %T] Done $0"
