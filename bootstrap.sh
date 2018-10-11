#!/bin/bash

#list of dependencies
declare -a PACKAGE_LIST=("zip"
"php7.0" 
"php7.0-mcrypt" 
"php7.0-curl" 
"php7.0-cli" 
"php7.0-mysql" 
"php7.0-mbstring"
"php7.0-imagick"
"php7.0-gd" 
"php7.0-dom" 
"php7.0-intl" 
"php-xdebug" 
"mysql-server" 
"apache2" 
"git")

PASSWORD='toor'
PROJECTFOLDER='app'
DATABASE='scadabr'

# verify if a package is alright installed
# in actual system
function package_exist() {
	if dpkg -s "$1" 2>&1 | grep -Eq 'install ok installed' ; then
		return 0
	else
		return 1
	fi
}

# add package
function add_package(){
	if apt install $1 -y >/dev/null 2>&1 ; then
		return 0
	else
		return 1
	fi
}

# function that verify if some package
# exist in atual repository
function in_repo(){
	if dpkg-query -s "$1" 1>/dev/null 2>&1 ; then
		return 0
	else
		return 1
	fi
}

# function that add repository
# and updating
function add_repo() {
	if ! package_exist software-properties-common ; then
		apt update &> /dev/null
		echo "adding 'add-apt-repository' tools..."
		if ! add_package software-properties-common ; then
			echo "Error: 'software-properties-common' installation failed." >&2
			exit 1
		fi
	fi
	echo "Adding repository:" $1
	add-apt-repository ppa:"$1" -y &> /dev/null
	apt update &> /dev/null
}

logo="$(cat <<"EOF"
  _______          _         ____   _  _   
 |__   __|        | |       |  _ \ (_)| |  
    | |  ___    __| |  ___  | |_) | _ | |_ 
    | | / _ \  / _` | / _ \ |  _ < | || __|
    | || (_) || (_| || (_) || |_) || || |_
    |_| \___/  \__,_| \___/ |____/ |_| \__|
                                           
    Vagrant Archtype
EOF
)"
echo "$logo"

echo "* pre-installing dependecies"

if ! in_repo php7.0-fpm ; then
	add_repo ondrej/php
fi

echo "* installing packages:"

# avoid prompt ask for root password in mysql-installation
debconf-set-selections <<< 'mysql-server mysql-server/root_password password '$PASSWORD >/dev/null 2>&1
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password '$PASSWORD >/dev/null 2>&1

for package in "${PACKAGE_LIST[@]}";
do
	echo "installing ${package}, please wait..."
    	add_package "${package}"
        if ! add_package "${package}" ; then
		    echo "Error: '${package}' fail installation failed." >&2
	    fi
done

echo "* configuring database, please wait..."

# make mysql secure
# remove acess root from remote
mysql -u root -p"$PASSWORD" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')" >/dev/null 2>&1
# remove anonymous access
mysql -u root -p"$PASSWORD" -e "DELETE FROM mysql.user WHERE User=''" >/dev/null 2>&1
# remove test database
mysql -u root -p"$PASSWORD" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'" >/dev/null 2>&1

#allow external acess
sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

# allow ip address (fix this later)
mysql -u root -p"$PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* to root@'33.33.33.10' IDENTIFIED BY '$PASSWORD';" >/dev/null 2>&1
mysql -u root -p"$PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* to root@'10.0.2.15' IDENTIFIED BY '$PASSWORD';" >/dev/null 2>&1
mysql -u root -p"$PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* to root@'localhost';" >/dev/null 2>&1

# flush everything
mysql -u root -p"$PASSWORD" -e "FLUSH PRIVILEGES" >/dev/null 2>&1

mysql -u root -p"$PASSWORD" -e "CREATE DATABASE ${DATABASE}" >/dev/null 2>&1

echo "* creating symbolic link to project directory in /var/www/html"
# create symbolic link to project directory
ln -s "/vagrant/${PROJECTFOLDER}" "/var/www/html/${PROJECTFOLDER}"

echo "* configuring xdebug"

# config remote xdebug
XDEBUG=$(cat <<EOF
[xdebug]
zend_extension=/usr/lib/php/20131226/xdebug.so
xdebug.remote_enable=1
xdebug.remote_host=10.0.2.2
xdebug.remote_port=9000
xdebug.remote_connect_back=0    # Not safe for production servers
xdebug.remote_handler=dbgp
xdebug.remote_mode=req
xdebug.remote_autostart=1
EOF
)

echo "* configuring apache"

echo "${XDEBUG}" >> /etc/php/7.0/apache2/php.ini

# config apache VirtualHost
VHOST=$(cat <<EOF
<VirtualHost *:80>
    DocumentRoot "/var/www/html/${PROJECTFOLDER}"
    ServerName localhost
    <Directory "/var/www/html/${PROJECTFOLDER}">
        Options FollowSymLinks
        AllowOverride All
        Order allow,deny
        Allow from all
    </Directory>
</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-available/000-default.conf

# enable mod_rewrite
a2enmod rewrite >/dev/null 2>&1

curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
apt-get install -y nodejs

# restart apache
service apache2 restart >/dev/null 2>&1

# install Composer
echo "* installing composer"
curl -s https://getcomposer.org/installer | php >/dev/null 2>&1
mv composer.phar /usr/local/bin/composer

echo "Done."

exit 0
