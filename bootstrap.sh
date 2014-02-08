#!/bin/bash
set -ex

if [ -z "$1" ]; then
	SUBDOMAIN=$(date | md5sum | head -c8)
else
	SUBDOMAIN=$1
fi

main() {
	apt-get update -y

	install-apache
	install-php
	install-mysql
	install-phpmyadmin
	install-ngrok
	install-magento
	configure-magento

	service apache2 restart
	service ngrok start

	print-urls
}

install-apache() {
	apt-get install -y apache2
}

install-php() {
	apt-get install -y libapache2-mod-php5 php5-cli
	a2enmod php5
	service apache2 restart
}

install-mysql() {
	sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
	sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
	apt-get install -y mysql-server libapache2-mod-auth-mysql php5-mysql
}

install-phpmyadmin() {
	echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections
	echo 'phpmyadmin phpmyadmin/app-password-confirm password ' | debconf-set-selections
	echo 'phpmyadmin phpmyadmin/mysql/admin-pass password root' | debconf-set-selections
	echo 'phpmyadmin phpmyadmin/mysql/app-pass password ' | debconf-set-selections
	echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections
	apt-get install -y phpmyadmin
}

install-ngrok() {
	apt-get install -y zip

	wget https://dl.ngrok.com/linux_386/ngrok.zip
	unzip ngrok.zip
	mv ngrok /usr/local/bin
	rm ngrok.zip

	cat > /vagrant/ngrok_subdomain.txt <<-EOF
	# Change this file and run `vagrant reload` to use a different ngrok subdomain
	# and update the base URL in Magento to reflect this. Lines starting with are
	# ignored.

	$SUBDOMAIN
	EOF

	cat > /etc/init/ngrok.conf <<-EOF
	start on (vagrant-mounted and started mysql and net-device-up IFACE!=lo)
	respawn

	pre-start script
		subdomain="\$(sed '/^\s*#/d' /vagrant/ngrok_subdomain.txt)"
		mysql -uroot -proot -Dmagento <<-EOMYSQL
			UPDATE core_config_data
				SET value='http://\\$subdomain.ngrok.com/magento/'
				WHERE path='/web/unsecure/base_url' OR path='web/secure/base_url';
			DELETE FROM core_config_data
				WHERE path='admin/url/use_custom' OR path='admin/url/custom';
			exit
		EOMYSQL
		rm -rf /vagrant/magento/var
	end script

	script
		subdomain="\$(sed '/^\s*#/d' /vagrant/ngrok_subdomain.txt)"
		ngrok -authtoken _dVbEk8--SnQSJS-Un7q -subdomain \$subdomain 80
	end script
	EOF

	# Do not start ngrok just yet because the Magento database is not setup.
}

install-magento() {
	service apache2 stop
	if [ ! -d /vagrant/magento ]; then
		cd /vagrant
		wget http://www.magentocommerce.com/downloads/assets/1.8.1.0/magento-1.8.1.0.tar.bz2
		tar -xf magento-1.8.1.0.tar.bz2 --checkpoint=.1000
		rm magento-1.8.1.0.tar.bz2
		cd magento

		apt-get install -y git
		git init .
		git add .
		git commit -m "Initial import"
	fi

	a2enmod rewrite

	# Enable .htaccess
	# http://fahdshariff.blogspot.com/2012/12/sed-mutli-line-replacement-between-two.html
	sed '/<Directory \/var\/www\/>/,/<\/Directory>/{s/AllowOverride None/AllowOverride All/}' \
		-i /etc/apache2/sites-available/default

	if [ ! -e /var/www/magento ]; then
		ln -s /vagrant/magento /var/www/magento
	fi
	service apache2 start
}

configure-magento() {
	mysql -uroot -proot <<-EOMYSQL
		CREATE DATABASE magento;
		GRANT ALL ON magento.* TO 'magento'@'localhost' IDENTIFIED BY 'magento';
		exit
	EOMYSQL
	rm -f /vagrant/magento/app/etc/local.xml
	php -f /vagrant/magento/install.php -- \
	    --license_agreement_accepted "yes" \
	    --locale "en_US" \
	    --timezone "America/Los_Angeles" \
	    --default_currency "USD" \
	    --db_host "localhost" \
	    --db_name "magento" \
	    --db_user "magento" \
	    --db_pass "magento" \
	    --url "http://$SUBDOMAIN.ngrok.com/magento" \
	    --use_rewrites "yes" \
	    --use_secure "no" \
	    --secure_base_url "http://$SUBDOMAIN.ngrok.com/magento" \
	    --use_secure_admin "no" \
	    --skip_url_validation "no" \
	    --admin_firstname "Store" \
	    --admin_lastname "Owner" \
	    --admin_email "store.owner@example.com" \
	    --admin_username "admin" \
	    --admin_password "password123" >&2
}

print-urls() {
	echo "Done. Your website is ready."
	echo "Frontend: http://$SUBDOMAIN.ngrok.com/magento"
	echo "Backend: http://$SUBDOMAIN.ngrok.com/magento/admin"
}

main