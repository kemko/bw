name "base"
description "common for all"
run_list "recipe[sysctl]", "recipe[timezone]", "recipe[apt]", "recipe[ntp]", "recipe[user::data_bag]", "recipe[base]", "recipe[sudo]", "recipe[lvm]"

default_attributes(
  'ruby' => {
    'ruby_build' => {
      'git_ref' => 'd410f6811defd71d872dc2acd9ee633f52fbf94a'
    },
    'chruby' => {
      'git_ref' => 'df6bde0573c2df1ec9bf959b717d0005dfaf936e'
    }
  }
)
