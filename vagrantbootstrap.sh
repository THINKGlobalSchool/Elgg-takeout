#!/usr/bin/env bash

VAGRANT_HOME="/home/vagrant"
VAGRANT_SYNC='/vagrant'
BOOTSTRAP_ROOT="$VAGRANT_HOME/.vagrantboostrap"

# Location of Spot manifest repository
SPOT_REPO="https://github.com/THINKGlobalSchool/spotrepo.git"

# Location of Spot base
SPOT_BASE="https://github.com/THINKGlobalSchool/Elgg.git"

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
	sudo apt-get install python-software-properties -qq 2>/dev/null
	sudo add-apt-repository ppa:git-core/ppa -qq 2>/dev/null
	sudo apt-get update 2>/dev/null

	# MySQL set root pwd
	sudo debconf-set-selections <<< 'mysql-server-5.5  mysql-server/root_password password root'
	sudo debconf-set-selections <<< 'mysql-server-5.5  mysql-server/root_password_again password root'
	sudo apt-get install mysql-server -qq 2>/dev/null

	# Install apache/php etc.
	apt-get install vim apache2 php5 libapache2-mod-php5 php5-mysql php5-gd php5-curl curl unzip imagemagick git php-apc -qq 2>/dev/null
	
	# Fix ServerName Errors
	echo ServerName $HOSTNAME > /etc/apache2/conf.d/fqdn

	# Enable modules
	sudo a2enmod rewrite
	sudo a2enmod headers
	sudo a2enmod expires

	# Change port in ports.conf and remove NameVirtualHost line
	sed -e '/NameVirtualHost/d' /etc/apache2/ports.conf 1> $VAGRANT_HOME/ports.conf
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

	# Latest version, change this to whichever branch/tag you want
	ELGG_BRANCH="1.10"
	ELGG_VERSION="1.10"

	# Elgg dirs
	ELGG_ROOT=$VAGRANT_SYNC/elgg
	ELGG_DATA_ROOT=$VAGRANT_HOME/elgg/elgg_data

	# Check if elgg directory already exists, if not check it out
	if [ ! -d "$ELGG_ROOT" ];
	then
		# Checkout Spot Elgg Fork
		git clone $SPOT_BASE $ELGG_ROOT

		# Checkout Elgg
		git clone -b $ELGG_BRANCH --single-branch $SPOT_BASE $ELGG_ROOT
		#git clone git://github.com/Elgg/Elgg.git $ELGG_ROOT # use this for master

		# Install Composer
		curl -sS https://getcomposer.org/installer | php -- --filename=composer
		mv composer /bin/composer
		
		pushd "$ELGG_ROOT" >> /dev/null
		
		# Checkout our branch
		git checkout $ELGG_BRANCH  # Comment out for master

		# Run composer
		composer install

		popd > /dev/null


		# !! Uncomment below to set up repo (and pull spot plugins)
		# Switch to elgg root
		#pushd "$ELGG_ROOT" >> /dev/null

		#echo "Initting repo..."
		
		# Init repo
		#repo init -q -u $SPOT_REPO

		#echo "Starting repo sync..."

		# Sync repo
		#repo sync -j 2 --no-clone-bundle --no-tags -q

		#popd > /dev/null
	fi

	# Set permissions on elgg directory
	#sudo chown vagrant:vagrant -R $VAGRANT_SYNC/elgg

	# Create elgg data folder, set permissions
	mkdir $VAGRANT_HOME/elgg
	mkdir $ELGG_DATA_ROOT
	sudo chown www-data:www-data $ELGG_DATA_ROOT

	# symlink ELGG_ROOT to current_root
	ln -s $ELGG_ROOT $VAGRANT_HOME/elgg/elgg_root

	cp /vagrant/config_files/default.conf /etc/apache2/sites-available/000-default.conf

	# make a super useful phpinfo file
	echo "<?php echo phpinfo(); ?>" > $VAGRANT_HOME/elgg/elgg_root/phpinfo.php

	service apache2 reload

	mysql -u root -proot <<< "CREATE DATABASE elgg"

	# Run install script (set up db, admin user, etc)
	echo "SETTING UP ELGG"
	php /vagrant/config_files/takeout_install.php


	sudo chown www-data:www-data -R $ELGG_DATA_ROOT
fi

echo "*************************************"
echo "* Spot Takeout: Bootstrap complete! *"
echo "* --------------------------------- *"
echo "*                                   *"
echo "* Visit: http://192.168.50.50       *"
echo "*                                   *"
echo "* Spot Login:                       *"
echo "* -----------                       *"
echo "* Username: admin                   *"
echo "* Password: administrator           *"
echo "*                                   *"
echo "*************************************"