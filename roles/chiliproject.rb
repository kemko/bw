name "chiliproject"
description "Install and configure chiliproject"
run_list "recipe[runit]", "recipe[postgresql]", "recipe[ruby]", "recipe[ssh_known_hosts]", "recipe[chiliproject]"

default_attributes(
  chiliproject: {
    application: {
      vagrant_port: 7070
    }
  }
)

