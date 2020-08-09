#!/bin/sh

MYSQL_NAME="{{ mysql_name }}"

/var/lib/mysql-${MYSQL_NAME}/bin/stop.sh
/var/lib/mysql-${MYSQL_NAME}/bin/start.sh
