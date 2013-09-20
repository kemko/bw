name "redmine"
description "Install and configure redmine"
run_list "recipe[runit]", "recipe[postgresql]", "recipe[ruby]", "recipe[redmine]"

default_attributes(
)
