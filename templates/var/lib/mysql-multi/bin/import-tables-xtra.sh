#!/bin/bash

set -a 

MYSQL_NAME="{{ mysql_name | default('my') }}"
MYSQL_CONFIG="{{ mysql_config | default('') }}"
MYSQL_XTRA_HOST="{{ mysql_master_host | default('') }}"
MYSQL_XTRA_PORT="{{ mysql_xtra_port | default('33301') }}"
MYSQL_REMOTE_CONFIG="${MYSQL_CONFIG}"
PARALLEL=4

set +a 

/usr/sbin/mysqlxtra $@  
