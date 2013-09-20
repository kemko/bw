# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
  config.vm.box = "lucid64"
  config.vm.box_url = "http://files.vagrantup.com/lucid64.box"

  # Forward guest port 80 to host port 8080
  config.vm.forward_port 80, 8080

  config.vm.provision :chef_solo do |chef|
    chef.json = {
        :mysql => {
            :server_root_password => 'banana',
            :server_repl_password => 'banana',
            :server_debian_password => 'banana',            
            :bind_address => '127.0.0.1'
        },
        :redmine => {
          :db => {
            :type => 'mysql',
            :user => 'root',
            :password => 'banana' 
          }
        }
    }
    chef.cookbooks_path = ["cookbooks"]
    chef.add_recipe "apt"
    chef.add_recipe "apache2"
    chef.add_recipe "mysql"
    chef.add_recipe "mysql::server"
    chef.add_recipe "rvm"
    chef.add_recipe "rails"
    chef.add_recipe "redmine"
  end
end