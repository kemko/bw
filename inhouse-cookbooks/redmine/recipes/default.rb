#
# Author: Joshua Timberman <joshua@housepub.org>
# Cookbook Name:: redmine
# Recipe:: default
#
# Copyright 2008-2009, Joshua Timberman
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

user = node[:redmine][:user]

%w(libpq5 libpq-dev imagemagick libmagickwand-dev).each { |p| package p }

user user do
  supports :manage_home => true
  shell "/bin/bash"
  home "/home/#{user}"
end

ruby_install node[:redmine][:ruby_version] do
  action :install
end

ruby_set node[:redmine][:ruby_version] do
  username user
end

bash "install_redmine" do
  cwd "/srv"
  user "root"
  code <<-EOH
    wget http://rubyforge.org/frs/download.php/#{node[:redmine][:dl_id]}/redmine-#{node[:redmine][:version]}.tar.gz
    tar xf redmine-#{node[:redmine][:version]}.tar.gz
    chown -R #{user} redmine-#{node[:redmine][:version]}
  EOH
  not_if { ::File.exists?("/srv/redmine-#{node[:redmine][:version]}/Rakefile") }
end

link "/srv/redmine" do
  to "/srv/redmine-#{node[:redmine][:version]}"
end

template "/srv/redmine/Gemfile"

execute "/opt/chruby/bin/chruby-exec #{node[:redmine][:ruby_version]} -- bundle install" do
  user user
  cwd "/srv/redmine"
  environment "HOME" => "/home/#{user}"
end

execute "/opt/chruby/bin/chruby-exec #{node[:redmine][:ruby_version]} -- rake generate_secret_token" do
  user user
  environment "HOME" => "/home/#{user}"
  cwd "/srv/redmine"
end

template "/srv/redmine-#{node[:redmine][:version]}/config/database.yml" do
  source "database.yml.erb"
  owner "root"
  group "root"
  variables :database_server => node[:redmine][:db][:hostname]
  mode "0664"
end

sysctl(
  "kernel.msgmax" => "65536",
  "kernel.shmall" => "4294967296",
  "kernel.shmmax" => "68719476736",
  "kernel.msgmnb" => "65536",
  "vm.swappiness" => "0",
  "vm.overcommit_memory" => "0",
  "fs.file-max" => "1048576"
)

postgresql "main" do
  databag "db"
  configuration(
    :version => "9.1",
    :resources => {
      :shared_buffers       => "32MB",
      :max_connections      => 10
    }
  )
  hba_configuration(
    [
      { :type => "host", :database => "all", :user => "all", :address => "127.0.0.1/32", :method => "trust" },
    ]
  )
end

execute "/opt/chruby/bin/chruby-exec #{node[:redmine][:ruby_version]} -- rake db:create db:migrate RAILS_ENV='production'" do
  user user
  environment "HOME" => "/home/#{user}"
  cwd "/srv/redmine-#{node[:redmine][:version]}"
  not_if { ::File.exists?("/srv/redmine-#{node[:redmine][:version]}/db/schema.rb") }
end

template "/srv/redmine/config/unicorn.rb" do
  source 'unicorn.rb.erb'
  owner user
  group user
  variables(
    :application_directory => "/srv/redmine",
    :listen => "*:8080",
    :worker_processes_num => 2,
    :user => user,
    :timeout => 180
  )
end

runit_service "#{user}_rails" do
  run_restart false
  template_name "redmine"
  options :home_path => "/home/#{user}",
          :app_path => "/srv/redmine",
          :target_user => user,
          :target_ruby => 'default',
          :target_env => 'production'
end

nginx_site "redmine"
