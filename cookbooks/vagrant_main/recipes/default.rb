require_recipe "apt"
require_recipe "apache2"
require_recipe "mysql::server"
require_recipe "php::php5"

# Some neat package (subversion is needed for "subversion" chef ressource)
%w{ debconf php5-xdebug subversion  }.each do |a_package|
  package a_package
end

# get phpmyadmin conf
cookbook_file "/tmp/phpmyadmin.deb.conf" do
  source "phpmyadmin.deb.conf"
end
bash "debconf_for_phpmyadmin" do
  code "debconf-set-selections /tmp/phpmyadmin.deb.conf"
end
package "phpmyadmin"

s = "local.dailypath.com"
site = {
  :name => s, 
  :host => "#{s}", 
  :aliases => ["#{s}"]
}

execute "install-fakemail" do
  command "sudo python #{@node[:vagrant][:directory]}/fakemail-python-1.0/setup.py install"
  action :run
  ignore_failure true
end

# Configure the development site
web_app site[:name] do
  template "sites.conf.erb"
  server_name site[:host]
  server_aliases site[:aliases]
  docroot	"#{@node[:vagrant][:directory]}/www/dailypath.com"
end  

# Add site info in /etc/hosts
bash "info_in_etc_hosts" do
  code "echo 127.0.0.1 #{site[:host]} #{site[:aliases]} >> /etc/hosts"
end

# Retrieve webgrind for xdebug trace analysis
subversion "Webgrind" do
  repository "http://webgrind.googlecode.com/svn/trunk/"
  revision "HEAD"
  destination "/var/www/webgrind"
  action :sync
end

# Add an admin user to mysql
execute "add-admin-user" do
  command "/usr/bin/mysql -u root -p#{node[:mysql][:server_root_password]} -e \"" +
      "CREATE USER 'myadmin'@'localhost' IDENTIFIED BY 'myadmin';" +
      "GRANT ALL PRIVILEGES ON *.* TO 'myadmin'@'localhost' WITH GRANT OPTION;" +
      "CREATE USER 'myadmin'@'%' IDENTIFIED BY 'myadmin';" +
      "GRANT ALL PRIVILEGES ON *.* TO 'myadmin'@'%' WITH GRANT OPTION;\" " +
      "mysql"
  action :run
  ignore_failure true
end

execute "chmod-app-tmp-directories" do
  command "chmod -R 777 #{@node[:vagrant][:directory]}/www/dailypath.com/app/tmp"
  action :run
  ignore_failure true
end

execute "start-fakemail" do
  command "sudo python /usr/local/bin/fakemail.py --host=localhost --port=10025 --path=/vagrant/emails --background"
  action :run
  ignore_failure true
end