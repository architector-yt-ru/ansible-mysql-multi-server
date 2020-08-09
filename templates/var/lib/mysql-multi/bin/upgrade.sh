#!/bin/bash

MYSQL_CONFIG="{{ mysql_config }}"

date +"[%F %T] Upgrade server"

mysql_upgrade --defaults-file=${MYSQL_CONFIG}

date +"[%F %T] Done $0"
