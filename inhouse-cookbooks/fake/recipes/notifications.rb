execute "echo 1" do
#  action :nothing
end

execute "echo 2" do
#  notifies :run, "execute[echo 1]", :delayed
end

execute "echo 3" do
#  notifies :run, "execute[echo 1]", :delayed
end

execute "echo 4"
