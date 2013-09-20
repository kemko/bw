name "zbx"
description "zabbix server and client"
run_list "recipe[php::default]", "recipe[nginx]", "recipe[fake::zabbix]", "recipe[zabbix-server::database]", "recipe[zabbix-server::server]", "recipe[zabbix-server::web]", "recipe[zabbix]", "recipe[partition]"#, "recipe[fake::zabbix-screens]"

default_attributes(
)
