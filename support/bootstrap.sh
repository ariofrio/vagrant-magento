#!/bin/bash
set -ex

SUPPLIED_SUBDOMAIN="$1"

main() {
	apt-get update -y

	apt-get install -y vim
	install-subdomain
	install-apache
	install-php
	install-composer
	install-mysql
	install-phpmyadmin
	install-ngrok
	install-magento
	configure-magento

	service apache2 restart
	service ngrok start

	print-urls
}

install-subdomain() {
	apt-get install -y dos2unix
	dos2unix < /vagrant/support/subdomain.sh > /usr/local/bin/subdomain
	chmod +x /usr/local/bin/subdomain
}

install-apache() {
	apt-get install -y apache2
}

install-php() {
	apt-get install -y libapache2-mod-php5 php5-cli php5-curl
	a2enmod php5
	service apache2 restart
}

install-composer() {
	apt-get install -y curl
	curl -sS https://getcomposer.org/installer | php
	mv composer.phar /usr/local/bin/composer
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

	# Migrate previous setups.
	if [ ! -f /vagrant/config/ngrok_subdomain.txt ]; then
		if [ -f /vagrant/ngrok_subdomain.txt ]; then
			mkdir -p /vagrant/config
			mv /vagrant/ngrok_subdomain.txt /vagrant/config/
		fi
	fi

	# Create the configuration file.
	if [ -n "$SUPPLIED_SUBDOMAIN" ] || [ ! -f /vagrant/config/ngrok_subdomain.txt ]; then
		if [ -z "$SUPPLIED_SUBDOMAIN" ]; then
			SUBDOMAIN=$(date | md5sum | head -c8)
		else
			SUBDOMAIN="$SUPPLIED_SUBDOMAIN"
		fi

		mkdir -p /vagrant/config
		cat > /vagrant/config/ngrok_subdomain.txt <<-EOF
		# Change this file and run \`vagrant reload\` to use a different
		# ngrok subdomain and update the base URL in Magento to reflect
		# this. Empty lines and lines starting with # are ignored.

		$SUBDOMAIN
		EOF
	fi

	# Make sure the file is easily editable on Windows.
	unix2dos /vagrant/config/ngrok_subdomain.txt

	dos2unix < /vagrant/support/ngrok.conf > /etc/init/ngrok.conf
	# Do not start ngrok just yet because the Magento database is not setup.
}

install-magento() {
	service apache2 stop
	if [ ! -d /vagrant/magento ]; then
		cd /vagrant
		apt-get install -y git
		git clone https://github.com/ariofrio/magento.git
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
	    --url "http://$(subdomain).ngrok.com/magento" \
	    --use_rewrites "yes" \
	    --use_secure "no" \
	    --secure_base_url "http://$(subdomain).ngrok.com/magento" \
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
	echo "Frontend: http://$(subdomain).ngrok.com/magento"
	echo "Backend: http://$(subdomain).ngrok.com/magento/admin"
}

main
