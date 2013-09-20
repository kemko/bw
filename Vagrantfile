Vagrant.configure("2") do |config|
  config.vm.define :etalon do |main|
    main.vm.box = "ubuntu12.04-chef11-chruby"
    main.vm.hostname = "etalon"
    config.vm.network :forwarded_port, guest: 8080, host: 7070
    main.vm.provider :virtualbox do |vb|
      vb.customize ["modifyvm", :id, "--memory", "2048"]
    end
    main.vm.provision :chef_solo do |chef|
      chef.log_level = :info
      chef.roles_path = "roles"
      chef.data_bags_path = "data_bags"
      # Here the path to secret file on local filesystem
      chef.encrypted_data_bag_secret_key_path = "./.chef/encrypted_data_bag_secret"

      chef.add_role "base"
      chef.add_role "redmine"
    end
  end
end
