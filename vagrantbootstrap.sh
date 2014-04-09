#!/usr/bin/env bash

VAGRANT_HOME="/home/vagrant"
VAGRANT_SYNC='/vagrant'
BOOTSTRAP_ROOT="$VAGRANT_HOME/.vagrantboostrap"

# Location of Spot manifest repository
SPOT_REPO="https://github.com/THINKGlobalSchool/spotrepo.git"

# Fix "stdin: is not a tty"
# 
# From: https://github.com/myplanetdigital/vagrant-ariadne/commit/dd0592d05d4f5c881640540fdc43d8396e00ddd7
#
# If last line is `mesg n`, replace with conditional.
if [ "`tail -1 /root/.profile`" = "mesg n" ]
then
  echo 'Fixing future `stdin: is not a tty` errors...'
  sed -i '$d' /root/.profile
  cat << 'EOH' >> /root/.profile
  if `tty -s`; then
    mesg n
  fi
EOH
fi

# Make sure bootstrap root exists
if [ ! -d $BOOTSTRAP_ROOT ];
then
	mkdir $BOOTSTRAP_ROOT
fi

# LAMP Install
if [ ! -f "$BOOTSTRAP_ROOT/LAMP" ];
then
	touch "$BOOTSTRAP_ROOT/LAMP"

	# Update first
	sudo apt-get update 2>/dev/null

	# Need to get latest git release (http://adammonsen.com/post/665)
	sudo apt-get install python-software-properties -y 2>/dev/null
	sudo add-apt-repository ppa:git-core/ppa -y 2>/dev/null
	sudo apt-get update 2>/dev/null

	# MySQL set root pwd
	sudo debconf-set-selections <<< 'mysql-server-5.5  mysql-server/root_password password root'
	sudo debconf-set-selections <<< 'mysql-server-5.5  mysql-server/root_password_again password root'
	sudo apt-get -y install mysql-server 2>/dev/null

	# Install apache/php etc.
	apt-get install vim apache2 php5 libapache2-mod-php5 php5-mysql php5-gd php5-curl curl unzip imagemagick git php-apc -y 2>/dev/null
	
	# Fix ServerName Errors
	echo ServerName $HOSTNAME > /etc/apache2/conf.d/fqdn

	# Enable modules
	sudo a2enmod rewrite
	sudo a2enmod headers
	sudo a2enmod expires

	# Change port in ports.conf and remove NameVirtualHost line
	sed -e '/NameVirtualHost/d' -e 's/80/8080/' /etc/apache2/ports.conf 1> $VAGRANT_HOME/ports.conf
	mv $VAGRANT_HOME/ports.conf /etc/apache2/ports.conf

	service apache2 restart
fi

# Install repo (see: https://code.google.com/p/git-repo)
if hash repo 2>/dev/null; then
	echo "Notice: Repo is already installed. Moving along."
else
	curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > /bin/repo
	chmod a+x /bin/repo
fi


# Elgg Install
if [ ! -f "$BOOTSTRAP_ROOT/elgg" ];
then
	touch "$BOOTSTRAP_ROOT/elgg"

	# Elgg dirs
	ELGG_ROOT=$VAGRANT_SYNC/elgg
	ELGG_DATA_ROOT=$VAGRANT_HOME/elgg/elgg_data

	# Check if elgg directory already exists, if not check it out
	if [ ! -d "$ELGG_ROOT" ];
	then
		mkdir "$ELGG_ROOT"

		# Switch to elgg root
		pushd "$ELGG_ROOT" >> /dev/null
		
		# Init repo
		repo init -u $SPOT_REPO

		# Sync repo
		repo sync

		popd > /dev/null
	fi

	# Set permissions on elgg directory
	chown vagrant:vagrant -R $VAGRANT_SYNC/elgg

	# Create elgg data folder, set permissions
	mkdir $VAGRANT_HOME/elgg
	mkdir $ELGG_DATA_ROOT
	chown www-data:www-data -R $ELGG_DATA_ROOT

	# symlink ELGG_ROOT to current_root
	ln -s $ELGG_ROOT $VAGRANT_HOME/elgg/elgg_root

	cp /vagrant/config_files/default /etc/apache2/sites-available/default

	# make a super useful phpinfo file
	echo "<?php echo phpinfo(); ?>" > $VAGRANT_HOME/elgg/elgg_root/phpinfo.php

	service apache2 reload

	mysql -u root -proot <<< "CREATE DATABASE elgg"

	# Run install script (set up db, admin user, etc)
	php /vagrant/elgg/mod/tgsadmin/scripts/spot_install.php

	# Run init script (set up plugin order and other tasks)
	php /vagrant/elgg/mod/tgsadmin/scripts/spot_init.php
fi

echo "*************************************"
echo "* Spot Takeout: Bootstrap complete! *"
echo "* --------------------------------- *"
echo "*                                   *"
echo "* Visit: http://127.0.0.1:8080      *"
echo "*                                   *"
echo "* Spot Login:                       *"
echo "* -----------                       *"
echo "* Username: spotadmin               *"
echo "* Password: admin                   *"
echo "*                                   *"
echo "*************************************"