disks = `find /sys/devices/pci* -type d | grep block/[a-z,0-9,\!]*$`.split("\n")

disks = disks.select do |disk|
  type = `cat #{disk}/device/type`.chomp.to_i
    type != 5 # dvd and so on
end

disks = disks.map { |disk| disk.split("\/").last.gsub("!", "\/") }

zabbix_screen node.fqdn do
  vsize(3 + disks.size * 2)

  screen_item "System: Load Average" do
    resource_type :graph
    width 900
    height 200
    y 0
  end

  screen_item "System: CPU Utilization" do
    resource_type :graph
    width 900
    height 200
    y 1
  end

  pos_y = 2

  disks.each do |disk|
    application = "Disk performance of /dev/#{disk}"

    screen_item "#{application}: io per second" do
      resource_type :graph
      width 900
      height 200
      y pos_y
    end

    pos_y += 1

    screen_item "#{application}: io latency" do
      resource_type :graph
      width 900
      height 200
      y pos_y
    end

    pos_y += 1
  end
end
