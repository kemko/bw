name "redmine"
description "Install and configure redmine"
run_list "recipe[runit]", "recipe[postgresql]", "recipe[ruby]", "recipe[redmine]"

default_attributes(
  'redmine' => {
    'pgsql_conn' => 50,
    'unucorn_proc' => 4
  }
)
