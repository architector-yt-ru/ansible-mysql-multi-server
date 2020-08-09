-- GRANTS

SET SQL_LOG_BIN = 0;
-- delete from `mysql`.`user` where not ((`user` = 'root' and `host` = 'localhost') or (user in ('service', 'repl') and `host` = '%'));
-- delete from `mysql`.`db` where not ((`user` = 'root' and `host` = 'localhost') or (user in ('service', 'repl') and `host` = '%'));
-- delete from `mysql`.`tables_priv` where not ((`user` = 'root' and `host` = 'localhost') or (user in ('service', 'repl') and `host` = '%'));
-- delete from `mysql`.`columns_priv` where not ((`user` = 'root' and `host` = 'localhost') or (user in ('service', 'repl') and `host` = '%'));
-- delete from `mysql`.`procs_priv` where not ((`user` = 'root' and `host` = 'localhost') or (user in ('service', 'repl') and `host` = '%'));
-- delete from `mysql`.`proxies_priv` where not ((`user` = 'root' and `host` = 'localhost') or (user in ('service', 'repl') and `host` = '%'));

-- root
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' IDENTIFIED BY '{{mysql_pass}}' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '{{mysql_pass}}' WITH GRANT OPTION;

-- haproxy
GRANT USAGE ON *.* TO 'haproxy'@'%';

-- service
GRANT SELECT, RELOAD, SUPER, REPLICATION SLAVE, REPLICATION CLIENT, SHOW VIEW, EVENT, TRIGGER ON *.* TO '{{mysql_master_user}}'@'%' IDENTIFIED BY '{{mysql_master_pass}}';
GRANT SELECT, RELOAD, SUPER, REPLICATION SLAVE, REPLICATION CLIENT, SHOW VIEW, EVENT, TRIGGER ON *.* TO '{{mysql_master_user}}'@'localhost' IDENTIFIED BY '{{mysql_master_pass}}';

-- exporter
GRANT SELECT, PROCESS, REPLICATION CLIENT ON *.* TO 'metrics'@'%' IDENTIFIED BY 'metrics';
GRANT SELECT, PROCESS, REPLICATION CLIENT ON *.* TO 'metrics'@'localhost' IDENTIFIED BY 'metrics';

FLUSH PRIVILEGES;
SET SQL_LOG_BIN = 1;
