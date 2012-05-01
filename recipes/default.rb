package "curl"

# Cookbook Name:: mongodb
# Recipe:: default
package_tgz = "mongodb-linux-x86_64-#{node[:mongodb][:version]}.tgz"
package_folder = package_tgz.gsub('.tgz', '')

user "mongodb" do
  comment "Mongodb user"
  home "/usr/local/mongodb"
  shell "/bin/bash"
  action :create
end

group "mongodb" do
  action :create
end

directory "/var/log/mongodb" do
  owner "mongodb"
  group "mongodb"
  mode 0755
  recursive true
  not_if { File.directory?('/var/log/mongodb') }
end

directory "/db/mongodb/master" do
  owner "mongodb"
  group "mongodb"
  mode 0755
  recursive true
  not_if { File.directory?('/db/mongodb/master') }
end

execute "install-mongodb" do
  command %Q{
      curl -O http://downloads.mongodb.org/linux/#{package_tgz} &&
      tar zxvf #{package_tgz} &&
      mv #{package_folder} /usr/local/mongodb &&
      rm #{package_tgz} &&
      echo #{node[:mongodb][:version]} > /usr/local/mongodb/VERSION
  }
  not_if { File.directory?('/usr/local/mongodb') }
end

execute "update-mongodb" do
  command %Q{
      curl -O http://downloads.mongodb.org/linux/#{package_tgz} &&
      tar zxvf #{package_tgz} &&
      rm -rf /usr/local/mongodb &&
      mv #{package_folder} /usr/local/mongodb &&
      rm #{package_tgz} &&
      echo #{node[:mongodb][:version]} > /usr/local/mongodb/VERSION
      /etc/init.d/mongodb restart
  }
  not_if " grep #{node[:mongodb][:version]} '/usr/local/mongodb/VERSION' "
end

execute "add-to-path" do
  command %Q{
      echo 'export PATH=$PATH:/usr/local/mongodb/bin' >> /etc/profile
  }
  not_if "grep 'export PATH=$PATH:/usr/local/mongodb/bin' /etc/profile"
end

template "/etc/mongodb.conf" do
  source "mongodb.conf.erb"
  owner "root"
  group "root"
  mode 0755
  variables(:port => 27017,
            :db_path => '/db/mongodb/master',
            :app_name => 'mongodb')
end

template "/etc/init.d/mongodb" do
  source "mongodb.erb"
  owner "root"
  group "root"
  mode 0755
  variables(:conf_file => '/etc/mongodb.conf',
            :data_dir => '/db/mongodb/master',
            :log_dir => '/var/log/mongodb',
            :name => 'mongodb')
end

execute "add-mongodb-to-default-run-level" do
  command %Q{
    update-rc.d -f  mongodb remove
    update-rc.d mongodb defaults
  }
end

execute "ensure-mongodb-is-running" do
  command %Q{
    /etc/init.d/mongodb start
  }
  not_if "pgrep mongod"
end
