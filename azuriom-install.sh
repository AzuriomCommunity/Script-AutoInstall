#!/bin/bash
#
# [Automatic installation on Linux for Azuriom]
#
# GitHub : https://github.com/MaximeMichaud/Azuriom-install
# URL : https://azuriom.com
#
# This script is intended for a quick and easy installation :
# bash <(curl -s https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/azuriom-install.sh)
#
# Azuriom-install Copyright (c) 2020-2022 Maxime Michaud
# Licensed under MIT License
#
#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to deal
#   in the Software without restriction, including without limitation the rights
#   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#   copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in all
#   copies or substantial portions of the Software.
#
#################################################################################
#Colors
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
normal=$(tput sgr0)
alert=${white}${on_red}
on_red=$(tput setab 1)
#################################################################################
function isRoot() {
  if [ "$EUID" -ne 0 ]; then
    return 1
  fi
}

function initialCheck() {
  if ! isRoot; then
    echo "Sorry, you need to run this as root"
    exit 1
  fi
  checkOS
}

function checkOS() {
  if [[ -e /etc/debian_version ]]; then
    OS="debian"
    source /etc/os-release

    if [[ "$ID" == "debian" || "$ID" == "raspbian" ]]; then
      if [[ ! $VERSION_ID =~ (9|10|11) ]]; then
        echo "⚠️ ${alert}Your version of Debian is not supported.${normal}"
        echo ""
        echo "However, if you're using older or unstable/testing then you can continue."
        echo "Keep in mind they may be no longer supported, though.${normal}"
        echo ""
        until [[ $CONTINUE =~ (y|n) ]]; do
          read -rp "Continue? [y/n] : " -e CONTINUE
        done
        if [[ "$CONTINUE" == "n" ]]; then
          exit 1
        fi
      fi
    elif [[ "$ID" == "ubuntu" ]]; then
      OS="ubuntu"
      if [[ ! $VERSION_ID =~ (18.04|20.04) ]]; then
        echo "⚠️ ${alert}Your version of Ubuntu is not supported.${normal}"
        echo ""
        echo "However, if you're using Older Ubuntu or beta, then you can continue."
        echo "Keep in mind they may be no longer supported, though.${normal}"
        echo ""
        until [[ $CONTINUE =~ (y|n) ]]; do
          read -rp "Continue? [y/n]: " -e CONTINUE
        done
        if [[ "$CONTINUE" == "n" ]]; then
          exit 1
        fi
      fi
    fi
  elif [[ -e /etc/centos-release ]]; then
    if ! grep -qs "^CentOS Linux release 7" /etc/centos-release; then
      echo "${alert}Your version of CentOS is not supported.${normal}"
      echo "${red}Keep in mind they are not supported, though.${normal}"
      echo ""
      unset CONTINUE
      until [[ $CONTINUE =~ (y|n) ]]; do
        read -rp "Continue? [y/n] : " -e CONTINUE
      done
      if [[ "$CONTINUE" == "n" ]]; then
        exit 1
      fi
    fi
  else
    echo "Looks like you aren't running this script on a Debian, Ubuntu or CentOS system ${normal}"
    exit 1
  fi
}

function script() {
  installQuestions
  updatepackages
  aptinstall
  aptinstall_php
  aptinstall_"$webserver"
  aptinstall_"$database"
  aptinstall_phpmyadmin
  install_composer
  install_azuriom
  autoUpdate
  setupdone

}
function installQuestions() {
  echo "${cyan}Welcome to Azuriom-install !"
  echo "https://github.com/MaximeMichaud/Azuriom-install"
  echo "I need to ask some questions before starting the configuration."
  echo "You can leave the default options and just press Enter if that's right for you."
  echo ""
  echo "${cyan}Which Version of PHP ?"
  echo "${red}Red = End of life ${yellow}| Yellow = Security fixes only ${green}| Green = Active support"
  echo "   1) PHP 8.1 (recommended) ${normal}"
  echo "   2) PHP 8 ${normal}"
  echo "${yellow}   3) PHP 7.4 ${normal}${cyan}"
  until [[ "$PHP_VERSION" =~ ^[1-3]$ ]]; do
    read -rp "Version [1-3]: " -e -i 1 PHP_VERSION
  done
  case $PHP_VERSION in
  1)
    PHP="8.1"
    ;;
  2)
    PHP="8.0"
    ;;
  3)
    PHP="7.4"
    ;;
  esac
  echo "Which type of webserver ?"
  echo "   1) NGINX"
  echo "   2) Apache2"
  until [[ "$WEBSERVER" =~ ^[1-2]$ ]]; do
    read -rp "Version [1-2]: " -e -i 1 WEBSERVER
  done
  case $WEBSERVER in
  1)
    webserver="nginx"
    ;;
  2)
    webserver="apache2"
    ;;
  esac
  if [[ "$webserver" =~ (nginx) ]]; then
    echo "Which branch of NGINX ?"
    echo "${green}   1) Mainline ${normal}"
    echo "${green}   2) Stable ${normal}${cyan}"
    until [[ "$NGINX_BRANCH" =~ ^[1-2]$ ]]; do
      read -rp "Version [1-2]: " -e -i 1 NGINX_BRANCH
    done
    case $NGINX_BRANCH in
    1)
      nginx_branch="mainline"
      ;;
    2)
      nginx_branch="stable"
      ;;
    esac
  fi
  echo "Which type of database ?"
  echo "   1) MariaDB"
  echo "   2) MySQL"
  echo "   3) SQLite (for dev)"
  until [[ "$DATABASE" =~ ^[1-3]$ ]]; do
    read -rp "Version [1-3]: " -e -i 1 DATABASE
  done
  case $DATABASE in
  1)
    database="mariadb"
    ;;
  2)
    database="mysql"
    ;;
  3)
    database="sqlite"
    ;;
  esac
  if [[ "$database" =~ (mysql) ]]; then
    echo "Which version of MySQL ?"
    echo "${green}   1) MySQL 8.0 ${normal}"
    echo "${red}   2) MySQL 5.7 ${normal}${cyan}"
    until [[ "$DATABASE_VER" =~ ^[1-2]$ ]]; do
      read -rp "Version [1-2]: " -e -i 1 DATABASE_VER
    done
    case $DATABASE_VER in
    1)
      database_ver="8.0"
      ;;
    2)
      database_ver="5.7"
      ;;
    esac
  fi
  if [[ "$database" =~ (mariadb) ]]; then
    echo "Which version of MariaDB ?"
    echo "${green}   1) MariaDB 10.6 (Stable)${normal}"
    echo "${yellow}   2) MariaDB 10.5 (Old Stable)${normal}"
    echo "${yellow}   3) MariaDB 10.4 (Old Stable)${normal}"
    echo "${yellow}   4) MariaDB 10.3 (Old Stable)${normal}${cyan}"
    until [[ "$DATABASE_VER" =~ ^[1-4]$ ]]; do
      read -rp "Version [1-4]: " -e -i 1 DATABASE_VER
    done
    case $DATABASE_VER in
    1)
      database_ver="10.6"
      ;;
    2)
      database_ver="10.5"
      ;;
    3)
      database_ver="10.4"
      ;;
    4)
      database_ver="10.3"
      ;;
    esac
  fi
  echo ""
  echo "We are ready to start the installation !"
  APPROVE_INSTALL=${APPROVE_INSTALL:-n}
  if [[ $APPROVE_INSTALL =~ n ]]; then
    read -n1 -r -p "Press any key to continue..."
  fi
}

function updatepackages() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    apt-get update && apt-get upgrade -y
  elif [[ "$OS" == "centos" ]]; then
    yum -y update
  fi
}

function aptinstall() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    apt-get -y install ca-certificates apt-transport-https dirmngr zip unzip lsb-release gnupg openssl curl wget
  fi
}

function aptinstall_apache2() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    apt-get install -y apache2
    a2enmod rewrite
    wget -O /etc/apache2/sites-available/000-default.conf https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/apache2/000-default.conf
    service apache2 restart
  fi
}

function aptinstall_nginx() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    apt-key adv --fetch-keys 'https://nginx.org/keys/nginx_signing.key'
    echo "deb https://nginx.org/packages/$nginx_branch/$OS/ $(lsb_release -sc) nginx" >/etc/apt/sources.list.d/nginx.list
    echo "deb-src https://nginx.org/packages/$nginx_branch/$OS/ $(lsb_release -sc) nginx" >>/etc/apt/sources.list.d/nginx.list
    apt-get update && apt-get install nginx -y
    systemctl enable nginx && systemctl start nginx
    rm -rf /etc/nginx/conf.d/default.conf
    mkdir -p /var/www
    mkdir -p /etc/nginx/globals/ || exit
    mkdir -p /etc/nginx/sites-available/ || exit
    mkdir -p /etc/nginx/sites-enabled/ || exit
    wget https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/nginx/nginx.conf -O /etc/nginx/nginx.conf
    wget https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/nginx/general.conf -O /etc/nginx/globals/general.conf
    wget https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/nginx/security.conf -O /etc/nginx/globals/security.conf
    wget https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/nginx/php_fastcgi.conf -O /etc/nginx/globals/php_fastcgi.conf
    wget https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/nginx/letsencrypt.conf -O /etc/nginx/globals/letsencrypt.conf
    wget https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/nginx/cloudflare-ip-list.conf -O /etc/nginx/globals/cloudflare-ip-list.conf
    wget https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/nginx/azuriom.conf -O /etc/nginx/sites-enabled/azuriom.conf
    sed -i "s|fastcgi_pass unix:/var/run/php/phpX.X-fpm.sock;|fastcgi_pass unix:/var/run/php/php$PHP-fpm.sock;|" /etc/nginx/sites-enabled/azuriom.conf
    openssl dhparam -out /etc/nginx/dhparam.pem 2048
  fi
}

function aptinstall_mariadb() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    echo "MariaDB Installation"
    apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    if [[ "$VERSION_ID" =~ (9|10|11|18.04|20.04) ]]; then
      echo "deb [arch=amd64] https://mirror.mva-n.net/mariadb/repo/$database_ver/$ID $(lsb_release -sc) main" >/etc/apt/sources.list.d/mariadb.list
      apt-get update && apt-get install mariadb-server -y
      systemctl enable mariadb && systemctl start mariadb
    fi
  fi
}

function aptinstall_mysql() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    echo "MYSQL Installation"
	apt-key adv --recv-keys --keyserver pgp.mit.edu 5072E1F5
    if [[ "$database_ver" == "8.0" ]]; then
      wget https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/mysql/default-auth-override.cnf -P /etc/mysql/mysql.conf.d
    fi
    if [[ "$VERSION_ID" =~ (9|10|11|18.04|20.04) ]]; then
      echo "deb http://repo.mysql.com/apt/$ID/ $(lsb_release -sc) mysql-$database_ver" >/etc/apt/sources.list.d/mysql.list
      echo "deb-src http://repo.mysql.com/apt/$ID/ $(lsb_release -sc) mysql-$database_ver" >>/etc/apt/sources.list.d/mysql.list
      apt-get update && apt-get install mysql-server mysql-client -y
      systemctl enable mysql && systemctl start mysql
    elif [[ "$OS" == "centos" ]]; then
      echo "No Support"
    fi
  fi
}

function aptinstall_sqlite() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    echo "SQLite Installation"
    if [[ "$VERSION_ID" =~ (9|10|11|18.04|20.04) ]]; then
      apt-get update && apt-get install php$PHP{,-sqlite} -y
    elif [[ "$OS" == "centos" ]]; then
      echo "No Support"
    fi
  fi
}

function aptinstall_php() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    echo "PHP Installation"
    curl -sSL -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    if [[ "$webserver" =~ (nginx) ]]; then
      if [[ "$VERSION_ID" =~ (9|10|11) ]]; then
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
        apt-get update && apt-get install php$PHP{,-bcmath,-mbstring,-common,-xml,-curl,-gd,-zip,-mysql,-fpm} -y
        sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/fpm/php.ini
        sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/fpm/php.ini
        sed -i 's|;max_input_vars = 1000|max_input_vars = 2000|' /etc/php/$PHP/fpm/php.ini
		sed -i 's|memory_limit = 128M|memory_limit = 256M|' /etc/php/$PHP/fpm/php.ini
        service php$PHP-fpm restart
        apt-get remove apache2 -y
        systemctl restart nginx
      fi
      if [[ "$VERSION_ID" =~ (18.04|20.04) ]]; then
        add-apt-repository -y ppa:ondrej/php
        apt-get update && apt-get install php$PHP{,-bcmath,-mbstring,-common,-xml,-curl,-gd,-zip,-mysql,-fpm} -y
        sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/fpm/php.ini
        sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/fpm/php.ini
        sed -i 's|;max_input_vars = 1000|max_input_vars = 2000|' /etc/php/$PHP/fpm/php.ini
		sed -i 's|memory_limit = 128M|memory_limit = 256M|' /etc/php/$PHP/fpm/php.ini
        service php$PHP-fpm restart
        apt-get remove apache2 -y
        systemctl restart nginx
      fi
    fi
    if [[ "$webserver" =~ (apache2) ]]; then
      if [[ "$VERSION_ID" =~ (9|10|11) ]]; then
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
        apt-get update && apt-get install php$PHP{,-bcmath,-mbstring,-common,-xml,-curl,-gd,-zip,-mysql} -y
        sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
        sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
        sed -i 's|;max_input_vars = 1000|max_input_vars = 2000|' /etc/php/$PHP/apache2/php.ini
		sed -i 's|memory_limit = 128M|memory_limit = 256M|' /etc/php/$PHP/fpm/php.ini
        service php$PHP-fpm restart
        systemctl restart apache2
      fi
      if [[ "$VERSION_ID" =~ (18.04|20.04) ]]; then
        add-apt-repository -y ppa:ondrej/php
        apt-get update && apt-get install php$PHP{,-bcmath,-mbstring,-common,-xml,-curl,-gd,-zip,-mysql} -y
        sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
        sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
        sed -i 's|;max_input_vars = 1000|max_input_vars = 2000|' /etc/php/$PHP/apache2/php.ini
		sed -i 's|memory_limit = 128M|memory_limit = 256M|' /etc/php/$PHP/fpm/php.ini
        service php$PHP-fpm restart
        systemctl restart apache2
      fi
    fi
  fi
}

function aptinstall_phpmyadmin() {
  echo "phpMyAdmin Installation"
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    PHPMYADMIN_VER=$(curl -s "https://api.github.com/repos/phpmyadmin/phpmyadmin/releases/latest" | grep -m1 '^[[:blank:]]*"name":' | cut -d \" -f 4)
    mkdir -p /usr/share/phpmyadmin/ || exit
    wget https://files.phpmyadmin.net/phpMyAdmin/"$PHPMYADMIN_VER"/phpMyAdmin-"$PHPMYADMIN_VER"-all-languages.tar.gz -O /usr/share/phpmyadmin/phpMyAdmin-"$PHPMYADMIN_VER"-all-languages.tar.gz
    tar xzf /usr/share/phpmyadmin/phpMyAdmin-"$PHPMYADMIN_VER"-all-languages.tar.gz --strip-components=1 --directory /usr/share/phpmyadmin
    rm -f /usr/share/phpmyadmin/phpMyAdmin-"$PHPMYADMIN_VER"-all-languages.tar.gz
    # Create phpMyAdmin TempDir
    mkdir -p /usr/share/phpmyadmin/tmp || exit
    chown www-data:www-data /usr/share/phpmyadmin/tmp
    chmod 700 /usr/share/phpmyadmin/tmp
    randomBlowfishSecret=$(openssl rand -base64 32)
    sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" /usr/share/phpmyadmin/config.sample.inc.php >/usr/share/phpmyadmin/config.inc.php
    ln -s /usr/share/phpmyadmin /var/www/phpmyadmin
	# if [[ "$webserver" =~ (nginx) ]]; then
      # apt-get update && apt-get install php8.0{,-bcmath,-mbstring,-common,-xml,-curl,-gd,-zip,-mysql,-fpm} -y
      # service nginx restart
	# fi
    if [[ "$webserver" =~ (apache2) ]]; then
      wget -O /etc/apache2/sites-available/phpmyadmin.conf https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/apache2/phpmyadmin.conf
      a2ensite phpmyadmin
      systemctl restart apache2
    fi
  elif [[ "$OS" == "centos" ]]; then
    echo "No Support"
  fi
}

function install_cron() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    cd /var/www/html || exit
    apt-get install cron -y
    crontab -l >cron
    wget -O cron https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/cron/cron
    crontab cron
    rm cron
  elif [[ "$OS" == "centos" ]]; then
    echo "No Support"
  fi
}

function install_composer() {
  if [[ "$OS" =~ (debian|ubuntu|centos) ]]; then
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
  fi
}

function mod_cloudflare() {
  #disabled for the moment
  a2enmod remoteip
  cd /etc/apache2 || exit
  wget -O /etc/apache2/apache2.conf https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/cloudflare/apache2.conf
  wget -O /etc/apache2/000-default.conf https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/cloudflare/000-default.conf
  wget -O /etc/apache2/conf-available/remoteip.conf https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/cloudflare/remoteip.conf
  systemctl restart apache2
}

function install_azuriom() {
  mkdir -p /var/www/html/
  rm -rf /var/www/html/*
  wget https://github.com/Azuriom/AzuriomInstaller/releases/latest/download/AzuriomInstaller.zip -O /var/www/html/AzuriomInstaller.zip
  unzip -o /var/www/html/AzuriomInstaller.zip -d /var/www/html/
  rm -r /var/www/html/AzuriomInstaller.zip
  chmod -R 755 /var/www/html
  chown -R www-data:www-data /var/www/html
  #AZURIOM_VER="$(
  #git ls-remote --tags https://github.com/Azuriom/Azuriom.git \
  #| cut -d/ -f3 \
  #| grep -vE -- '-rc|-b' \
  #| sed -E 's/^v//' \
  #| sort -V \
  #| tail -1 )"
  #wget https://github.com/Azuriom/Azuriom/releases/download/v$AZURIOM_VER/Azuriom-$AZURIOM_VER.zip
  #unzip -q Azuriom-$AZURIOM_VER.zip
  #rm -rf Azuriom-$AZURIOM_VER.zip
}

function autoUpdate() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    echo "Enable Automatic Updates..."
    apt-get install -y unattended-upgrades
  elif [[ "$OS" == "centos" ]]; then
    echo "No Support"
  fi
}

function setupdone() {
  IP=$(curl 'https://api.ipify.org')
  echo "${cyan}It done!"
  echo "${cyan}Configuration Database/User: ${red}http://$IP/index.php"
  echo "${cyan}phpMyAdmin: ${red}http://$IP/phpmyadmin"
  echo "${cyan}For the moment, If you choose to use MariaDB, you will need to execute ${normal}${on_red}${white}mysql_secure_installation${normal}${cyan} for setting the password"
}
function manageMenu() {
  clear
  echo "Welcome to Azuriom-install !"
  echo "https://github.com/MaximeMichaud/Azuriom-install"
  echo ""
  echo "It seems that the Script has already been used in the past."
  echo ""
  echo "What do you want to do ?"
  echo "   1) Restart the installation"
  echo "   2) Update phpMyAdmin"
  echo "   3) Add certs (https)"
  echo "   4) Update the Script"
  echo "   5) Quit"
  until [[ "$MENU_OPTION" =~ ^[1-5]$ ]]; do
    read -rp "Select an option [1-5] : " MENU_OPTION
  done
  case $MENU_OPTION in
  1)
    script
    ;;
  2)
    updatephpMyAdmin
    ;;
  3)
    install_letsencrypt
    ;;
  4)
    update
    ;;
  5)
    exit 0
    ;;
  esac
}

function update() {
  wget https://raw.githubusercontent.com/MaximeMichaud/azuriom-install/master/azuriom-install.sh -O azuriom-install.sh
  chmod +x azuriom-install.sh
  echo ""
  echo "Update Done."
  sleep 2
  ./azuriom-install.sh
  exit
}

function updatephpMyAdmin() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    rm -rf /usr/share/phpmyadmin/*
    cd /usr/share/phpmyadmin/ || exit
    PHPMYADMIN_VER=$(curl -s "https://api.github.com/repos/phpmyadmin/phpmyadmin/releases/latest" | grep -m1 '^[[:blank:]]*"name":' | cut -d \" -f 4)
    wget https://files.phpmyadmin.net/phpMyAdmin/"$PHPMYADMIN_VER"/phpMyAdmin-"$PHPMYADMIN_VER"-all-languages.tar.gz -O /usr/share/phpmyadmin/phpMyAdmin-"$PHPMYADMIN_VER"-all-languages.tar.gz
    tar xzf /usr/share/phpmyadmin/phpMyAdmin-"$PHPMYADMIN_VER"-all-languages.tar.gz --strip-components=1 --directory /usr/share/phpmyadmin
    rm -f /usr/share/phpmyadmin/phpMyAdmin-"$PHPMYADMIN_VER"-all-languages.tar.gz
    # Create TempDir
    mkdir /usr/share/phpmyadmin/tmp || exit
    chown www-data:www-data /usr/share/phpmyadmin/tmp
    chmod 700 /var/www/phpmyadmin/tmp
    randomBlowfishSecret=$(openssl rand -base64 32)
    sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" /usr/share/phpmyadmin/config.sample.inc.php >/usr/share/phpmyadmin/config.inc.php
  elif [[ "$OS" == "centos" ]]; then
    echo "No Support"
  fi
}

initialCheck

if [[ -e /var/www/html/public/ ]]; then
  manageMenu
else
  script
fi
