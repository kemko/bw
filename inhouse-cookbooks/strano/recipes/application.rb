#
# Cookbook Name:: strano
# Recipe:: application
#
# Copyright 2012, LLC Express 42
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

class Chef::Recipe
    include Express42::Base::Network
end

if Chef::Config[:solo]
  Chef::Log.warn("This recipe uses search. Chef Solo does not support search. I will return current node")
  postgresql_master_node = node
  application_nodes = [ node ]
else
  postgresql_master_node = search(:node, "role:postgresql-master AND chef_environment:#{node.chef_environment}").first
  application_nodes = search(:node, "role:application AND chef_environment:#{node.chef_environment}")
  frontend_nodes = search(:node, "role:strano-frontend AND chef_environment:#{node.chef_environment}")
end

postgresql_master_server = net_get_private(postgresql_master_node)[0][1]

application_servers_ip = application_nodes.map{|node| net_get_all_ip(node)}.flatten.uniq

if frontend_nodes
  frontend_servers_ip = frontend_nodes.map{|server| net_get_public(server)[0][1] }
  frontend_servers_ip.flatten!
else
  frontend_servers_ip = []
end

block_device = "/dev/#{node["strano"]["application"]["lvm_group"]}/#{node["strano"]["application"]["lvm_volume"]}"
user = node["strano"]["application"]["application_user"]
application_directory = node["strano"]["application"]["application_directory"]
rails_environment = node["strano"]["application"]["rails_environment"] 
lvm_volume = node["strano"]["application"]["lvm_volume"]
lvm_group = node["strano"]["application"]["lvm_group"]
lvm_size = node["strano"]["application"]["volume_size"]

partition lvm_volume do
  group lvm_group
  size lvm_size
  filesystem 'ext4'
  mount_point application_directory
  create_partition node["strano"]["application"]["create_partitions"] == "yes"
end

user_account user

directory "#{application_directory}/" do
  owner user
  group user
end

link "/home/#{user}/#{lvm_volume}" do
  to "#{application_directory}"
end

ruby_install node["strano"]["ruby_version"] do
  action :install
end

ruby_set node["strano"]["ruby_version"] do
  username user
end

git "#{application_directory}/current" do
  user user
  group user
  repository "git://github.com/express42/strano.git"
  reference "v_0_1"
  action :sync
end

template "#{application_directory}/current/config/database.yml" do
  source 'database.yml.erb'
  owner user
  group user
  variables :db_name => node["strano"]["application"]["database_name"],
    :password => "dbpassword",
    :username => "dbuser",
    :host => postgresql_master_server
end

template "#{application_directory}/current/config/strano.yml" do
  source 'strano.yml.erb'
  owner user
  group user
end

template "#{application_directory}/current/config/unicorn.rb" do
  source 'unicorn.rb.erb'
  owner user
  group user
  variables :app_path => application_directory,
            :worker_processes => 2,
            :listen => "/tmp/strano-rails.sock"
end

template "/home/#{user}/.ssh/config" do
  source 'ssh_config'
  owner user
  group user
end

execute "bundle install" do
  cwd "#{application_directory}/current"
  command "/opt/chruby/bin/chruby-exec #{node["strano"]["ruby_version"]} -- bundle install --deployment"
  creates "#{application_directory}/current/deploy.lock"
  user user
  group user
  environment 'HOME' => "/home/#{user}"
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
end

execute "db migrations" do
  cwd "#{application_directory}/current"
  command "/opt/chruby/bin/chruby-exec #{node["strano"]["ruby_version"]} -- bundle exec rake db:migrate"
  creates "#{application_directory}/current/deploy.lock"
  user user
  group user
  environment 'HOME' => "/home/#{user}", 'RAILS_ENV' => rails_environment
end

execute "assets precompile" do
  cwd "#{application_directory}/current"
  command "/opt/chruby/bin/chruby-exec #{node["strano"]["ruby_version"]} -- bundle exec rake assets:precompile"
  creates "#{application_directory}/current/deploy.lock"
  user user
  group user
  environment 'HOME' => "/home/#{user}", 'RAILS_ENV' => rails_environment
end

execute "create deploy lock" do
  cwd "#{application_directory}/current"
  command "touch #{application_directory}/current/deploy.lock"
  user user
  group user
end

runit_service "strano_rails" do
  template_name "rails_app"
  run_restart false
  options :home_path => "/home/#{user}",
          :app_path => "#{application_directory}",
          :target_user => user,
          :target_ruby => "default",
          :target_env => rails_environment
end

template "#{node[:nginx][:directories][:conf_dir]}/strano-site-htpasswd" do
  source "strano-site-htpasswd.erb"
  owner "www-data"
  group "www-data"
  mode 0640
end

runit_service "strano-worker-1" do
  run_restart false
  template_name "strano-worker"
  options "home_path" => "/home/#{user}",
          "app_path" => application_directory,
          "target_user" => user,
          "target_ruby" => "default",
          "target_env" => rails_environment
end

sudo "strano" do
  user user
  commands ["/usr/bin/sv * strano_*"]
  host "ALL"
  nopasswd true
end

nginx_site "nginx-strano-application" do
  variables :app_path => application_directory,
            :application_servers_ip => application_servers_ip,
            :frontend_servers_ip => frontend_servers_ip,
            :backend => "unix:/tmp/strano-rails.sock",
            :vagrant_port => node["strano"]["application"]["vagrant_port"]
end

ssh_known_hosts_entry 'github.com'

key = Chef::EncryptedDataBagItem.load('deploy-key', 'key')

file "/home/#{user}/.ssh/id_rsa" do
  content key['private_key']
  owner user
  group user
  mode '0600'
end
