maintainer        "Opscode, Inc."
maintainer_email  "cookbooks@opscode.com"
license           "Apache 2.0"
description       "Installs and configures redmine as a Rails app with unicorn"
version           "2.0.0"

recipe "redmine", "Installs and configures redmine under unicorn"

%w{ ubuntu debian }.each do |os|
  supports os
end
