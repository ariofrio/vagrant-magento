#!/bin/bash
set -e
apt-get update

# Install Apache
apt-get install -y apache2

# Install PHP
apt-get install -y libapache2-mod-php5
a2enmod php5

# Install MySQL
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
apt-get install -y mysql-server libapache2-mod-auth-mysql php5-mysql

# Install phpMyAdmin
echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/app-password-confirm password ' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/admin-pass password root' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/app-pass password ' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections
apt-get install -y phpmyadmin

# Install ngrok
apt-get install -y zip
wget https://dl.ngrok.com/linux_386/ngrok.zip
unzip ngrok.zip
mv ngrok /usr/local/bin
rm ngrok.zip

if [ -z "$1" ]; then
	SUBDOMAIN=$(date | md5sum | head -c8)
else
	SUBDOMAIN=$1
fi
echo $SUBDOMAIN > /etc/ngrok_subdomain

cat > /etc/init/ngrok.conf <<EOF
start on net-device-up IFACE!=lo
respawn

exec ngrok -authtoken _dVbEk8--SnQSJS-Un7q -subdomain $(cat /etc/ngrok_subdomain) 80
EOF
start ngrok

# Install Magento
if [ ! -d /vagrant/magento ]; then
	cd /vagrant
	wget http://www.magentocommerce.com/downloads/assets/1.8.1.0/magento-1.8.1.0.tar.bz2
	tar -xf magento-1.8.1.0.tar.bz2
	rm magento-1.8.1.0.tar.bz2
	cd magento

	apt-get install -y git
	git init .
	git add .
	git commit -m "Initial import"
	cd -
fi
a2enmod rewrite
ln -s /vagrant/magento /var/www/magento

# Reload Apache configuration
service apache2 restart