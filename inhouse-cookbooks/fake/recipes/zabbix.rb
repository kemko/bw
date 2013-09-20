zabbix_connect "connect to kupikupon zabbix" do
  apiurl "http://127.0.0.1/api_jsonrpc.php"
  user "Admin"
  password "zabbix"
end

ip_mon = net_get_private(node).empty? ? net_get_public(node)[0][1] : net_get_private(node)[0][1]

zabbix_host node.fqdn do
  host_group "Fake client"
  use_ip true
  ip_address ip_mon
end

cookbook_file "zbx_templates.xml" do
  path "/tmp/zbx_templates.xml"
end

zabbix_template "/tmp/zbx_templates.xml" do
  action :import
end

zabbix_template 'Linux_Template'

## Just for test
zabbix_media_type "sms" do
  type :sms
  modem "/dev/modem"
end

zabbix_user_group 'My Beloved group'

zabbix_action 'My favorite action' do
  event_source :triggers
  operation do
    user_groups 'My Beloved group'
    message do
      use_default_message false
      subject "Test {TRIGGER.SEVERITY}: {HOSTNAME1} {TRIGGER.STATUS}: {TRIGGER.NAME}"
      message "Trigger: {TRIGGER.NAME}\n"+
        "Trigger status: {TRIGGER.STATUS}\n" +
        "Trigger severity: {TRIGGER.SEVERITY}\n" +
        "\n" +
        "Item values:\n" +
        "{ITEM.NAME1} ({HOSTNAME1}:{TRIGGER.KEY1}): {ITEM.VALUE1}"
      media_type "sms"
    end
  end

  condition :trigger_severity, :gte, :high
#  condition :host_group, :equal, "Fake Client"
  condition :maintenance, :not_in, :maintenance
end

zabbix_user_macro 'my_macro' do
  value 'foobar'
end
