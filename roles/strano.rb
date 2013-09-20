name "strano"
description "Install and configure redmine"
run_list "recipe[user]", "recipe[postgresql]", "recipe[partition]", "recipe[ruby]", "recipe[runit]", "recipe[nginx]", "recipe[ssh_known_hosts]", "recipe[strano::application]"

default_attributes(
  strano: {
    application: {
      github_key: "305bd9ae51bcd0190d9a",
      github_secret: "ccc096152a559e27c9304bb9ae4f896b81a3832c",
      vagrant_port: 7071
    }
  }
)
