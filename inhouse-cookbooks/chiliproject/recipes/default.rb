#
# Cookbook Name:: chiliproject
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
  application_nodes = [ node ]
else
  application_nodes = search(:node, "role:application AND chef_environment:#{node.chef_environment}")
  frontend_nodes = search(:node, "role:chiliproject-frontend AND chef_environment:#{node.chef_environment}")
end

application_servers_ip = application_nodes.map{|node| net_get_all_ip(node)}.flatten.uniq

if frontend_nodes
  frontend_servers_ip = frontend_nodes.map{|server| net_get_public(server)[0][1] }
  frontend_servers_ip.flatten!
else
  frontend_servers_ip = []
end

block_device = "/dev/#{node["chiliproject"]["application"]["lvm_group"]}/#{node["chiliproject"]["application"]["lvm_volume"]}"
user = node["chiliproject"]["application"]["application_user"]
application_directory = node["chiliproject"]["application"]["application_directory"]
rails_environment = node["chiliproject"]["application"]["rails_environment"] 
lvm_volume = node["chiliproject"]["application"]["lvm_volume"]
lvm_group = node["chiliproject"]["application"]["lvm_group"]
lvm_size = node["chiliproject"]["application"]["volume_size"]

%w(libpq5 libpq-dev imagemagick libmagickwand-dev).each { |p| package p }

partition lvm_volume do
  group lvm_group
  size lvm_size
  filesystem 'ext4'
  mount_point application_directory
  create_partition node["chiliproject"]["application"]["create_partitions"] == "yes"
end

key = Chef::EncryptedDataBagItem.load('deploy-key', 'key')

user_account user do
  ssh_keys key['public_key']
end

directory application_directory do
  owner user
  group user
end

directory "#{application_directory}/shared" do
  owner user
  group user
end

directory "#{application_directory}/shared/config" do
  owner user
  group user
end

link "/home/#{user}/#{lvm_volume}" do
  to "#{application_directory}"
end


app_path = "/home/#{user}/#{lvm_volume}/current"

ruby_install node["chiliproject"]["ruby_version"] do
  action :install
end

ruby_set node["chiliproject"]["ruby_version"] do
  username user
end

template "#{application_directory}/shared/config/database.yml" do
  source 'database.yml.erb'
  owner user
  group user
  variables :db_name => node["chiliproject"]["application"]["database_name"]
end

template "#{application_directory}/shared/config/chiliproject.yml" do
  source 'settings.yml.erb'
  owner user
  group user
end

template "#{application_directory}/shared/config/Gemfile" do
  owner user
  group user
end

template "#{application_directory}/shared/config/session_store.rb" do
  owner user
  group user
  variables :secret => node["chiliproject"]["application"]["secret"]
end

template "#{application_directory}/shared/config/unicorn.rb" do
  source 'unicorn.rb.erb'
  owner user
  group user
  variables :app_path => app_path,
            :user => user,
            :timeout => 30,
            :worker_processes => 2,
            :listen => "/tmp/chiliproject-rails.sock"
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

runit_service "chiliproject_rails" do
  template_name "chiliproject"
  run_restart false
  options :home_path => "/home/#{user}",
          :app_path => app_path,
          :target_user => user,
          :target_ruby => "default",
          :target_env => "production"
end

sudo "chiliproject" do
  user user
  commands ["/usr/bin/sv * chiliproject_*"]
  host "ALL"
  nopasswd true
end

nginx_site "chiliproject" do
  variables :app_path => application_directory,
            :application_servers_ip => application_servers_ip,
            :frontend_servers_ip => frontend_servers_ip,
            :backend => "unix:/tmp/chiliproject-rails.sock",
            :vagrant_port => node["chiliproject"]["application"]["vagrant_port"]
end

ssh_known_hosts_entry 'github.com'

# key = Chef::EncryptedDataBagItem.load('deploy-key', 'key')
#
# file "/home/#{user}/.ssh/id_rsa" do
#   content key['private_key']
#   owner user
#   group user
#   mode '0600'
# end

