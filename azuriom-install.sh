#!/bin/bash
#
# [Automatic installation on Linux for Azurium]
#
# GitHub : https://github.com/MaximeMichaud/Azuriom-install
# URL : https://azuriom.com/
#
# This script is intended for a quick and easy installation :
# wget https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/azuriom-install.sh
# chmod +x azuriom-install.sh
# ./azuriom-install.sh
#
# Azuriom-install Copyright (c) 2020 Maxime Michaud
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
#Couleurs
black=$(tput setaf 0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
on_red=$(tput setab 1)
on_green=$(tput setab 2)
on_yellow=$(tput setab 3)
on_blue=$(tput setab 4)
on_magenta=$(tput setab 5)
on_cyan=$(tput setab 6)
on_white=$(tput setab 7)
bold=$(tput bold)
dim=$(tput dim)
underline=$(tput smul)
reset_underline=$(tput rmul)
standout=$(tput smso)
reset_standout=$(tput rmso)
normal=$(tput sgr0)
alert=${white}${on_red}
title=${standout}
sub_title=${bold}${yellow}
repo_title=${black}${on_green}
message_title=${white}${on_magenta}
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

# Define versions
PHPMYADMIN_VER=5.0.2
AZURIOM_VER=0.2.3

function checkOS() {
  if [[ -e /etc/debian_version ]]; then
    OS="debian"
    source /etc/os-release

    if [[ "$ID" == "debian" || "$ID" == "raspbian" ]]; then
      if [[ ! $VERSION_ID =~ (9|10|11) ]]; then
        echo "⚠️ ${alert}Your version of Debian is not supported.${normal}"
        echo ""
        echo "However, if you're using Debian >= 9 or unstable/testing then you can continue."
        echo "Keep in mind they are not supported, though.${normal}"
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
      if [[ ! $VERSION_ID =~ (16.04|18.04|20.04) ]]; then
        echo "⚠️ ${alert}Your version of Ubuntu is not supported.${normal}"
        echo ""
        echo "However, if you're using Ubuntu > 17 or beta, then you can continue."
        echo "Keep in mind they are not supported, though.${normal}"
        echo ""
        until [[ $CONTINUE =~ (y|n) ]]; do
          read -rp "Continue? [y/n]: " -e CONTINUE
        done
        if [[ "$CONTINUE" == "n" ]]; then
          exit 1
        fi
      fi
    fi
  elif [[ -e /etc/fedora-release ]]; then
    OS=fedora
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
    echo "Looks like you aren't running this script on a Debian, Ubuntu, Fedora, CentOS system ${normal}"
    exit 1
  fi
}

function script() {
  installQuestions
  aptupdate
  aptinstall
  aptinstall_apache2
  aptinstall_mysql
  aptinstall_php
  aptinstall_phpmyadmin
  install_azuriom
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
  echo "${yellow}   1) PHP 7.2 "
  echo "${green}   2) PHP 7.3 "
  echo "   3) PHP 7.4 (recommended) ${normal}${cyan}"
  until [[ "$PHP_VERSION" =~ ^[1-3]$ ]]; do
    read -rp "Version [1-3]: " -e -i 3 PHP_VERSION
  done
  case $PHP_VERSION in
  1)
    PHP="7.2"
    ;;
  2)
    PHP="7.3"
    ;;
  3)
    PHP="7.4"
    ;;
  esac
  echo ""
  echo "We are ready to start the installation !"
  APPROVE_INSTALL=${APPROVE_INSTALL:-n}
  if [[ $APPROVE_INSTALL =~ n ]]; then
    read -n1 -r -p "Press any key to continue..."
  fi
}

function aptupdate() {
  apt-get update
}
function aptinstall() {
  apt-get -y install ca-certificates apt-transport-https dirmngr zip unzip lsb-release gnupg openssl curl
}

function aptinstall_apache2() {
  apt-get install -y apache2
  a2enmod rewrite
  wget https://raw.githubusercontent.com/MaximeMichaud/Azuriom-install/master/conf/000-default.conf
  mv 000-default.conf /etc/apache2/sites-available/
  rm -rf 000-default.conf
  service apache2 restart
}

function aptinstall_mysql() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    echo "MYSQL Installation"
    wget https://github.com/MaximeMichaud/Azuriom-install/blob/master/conf/default-auth-override.cnf -P /etc/mysql/mysql.conf.d
    if [[ "$VERSION_ID" == "9" ]]; then
      echo "deb http://repo.mysql.com/apt/debian/ stretch mysql-8.0" >/etc/apt/sources.list.d/mysql.list
      echo "deb-src http://repo.mysql.com/apt/debian/ stretch mysql-8.0" >>/etc/apt/sources.list.d/mysql.list
      apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
      apt-get update
      apt-get install --allow-unauthenticated mysql-server mysql-client -y
      systemctl enable mysql && systemctl start mysql
    fi
    if [[ "$VERSION_ID" == "10" ]]; then
      echo "deb http://repo.mysql.com/apt/debian/ buster mysql-8.0" >/etc/apt/sources.list.d/mysql.list
      echo "deb-src http://repo.mysql.com/apt/debian/ buster mysql-8.0" >>/etc/apt/sources.list.d/mysql.list
      apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
      apt-get update
      apt-get install --allow-unauthenticated mysql-server mysql-client -y
      systemctl enable mysql && systemctl start mysql
    fi
    if [[ "$VERSION_ID" == "11" ]]; then
      # not available right now
      echo "deb http://repo.mysql.com/apt/debian/ bullseye mysql-8.0" >/etc/apt/sources.list.d/mysql.list
      echo "deb-src http://repo.mysql.com/apt/debian/ bullseye mysql-8.0" >>/etc/apt/sources.list.d/mysql.list
      apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
      apt-get update
      apt-get install --allow-unauthenticated mysql-server mysql-client -y
      systemctl enable mysql && systemctl start mysql
    fi
    if [[ "$VERSION_ID" == "16.04" ]]; then
      echo "deb http://repo.mysql.com/apt/ubuntu/ xenial mysql-8.0" >/etc/apt/sources.list.d/mysql.list
      echo "deb-src http://repo.mysql.com/apt/ubuntu/ xenial mysql-8.0" >>/etc/apt/sources.list.d/mysql.list
      apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
      apt-get update
      apt-get install --allow-unauthenticated mysql-server mysql-client -y
      systemctl enable mysql && systemctl start mysql
    fi
    if [[ "$VERSION_ID" == "18.04" ]]; then
      echo "deb http://repo.mysql.com/apt/ubuntu/ bionic mysql-8.0" >/etc/apt/sources.list.d/mysql.list
      echo "deb-src http://repo.mysql.com/apt/ubuntu/ bionic mysql-8.0" >>/etc/apt/sources.list.d/mysql.list
      apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
      apt-get update
      apt-get install --allow-unauthenticated mysql-server mysql-client -y
      systemctl enable mysql && systemctl start mysql
    fi
    if [[ "$VERSION_ID" == "20.04" ]]; then
      echo "deb http://repo.mysql.com/apt/ubuntu/ focal mysql-8.0" >/etc/apt/sources.list.d/mysql.list
      echo "deb-src http://repo.mysql.com/apt/ubuntu/ focal mysql-8.0" >>/etc/apt/sources.list.d/mysql.list
      apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
      apt-get update
      apt-get install --allow-unauthenticated mysql-server mysql-client -y
      systemctl enable mysql && systemctl start mysql
    fi
  fi
}

function aptinstall_php() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    echo "PHP Installation"
    wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add -
    if [[ "$VERSION_ID" == "9" ]]; then
      echo "deb https://packages.sury.org/php/ stretch main" | tee /etc/apt/sources.list.d/php.list
      apt-get update >/dev/null
      apt-get install php$PHP php$PHP-bcmath php$PHP-json php$PHP-mbstring php$PHP-common php$PHP-xml php$PHP-curl php$PHP-gd php$PHP-zip php$PHP-mysql php$PHP-sqlite -y
      sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
      sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
      systemctl restart apache2
    fi
    if [[ "$VERSION_ID" == "10" ]]; then
      echo "deb https://packages.sury.org/php/ buster main" | tee /etc/apt/sources.list.d/php.list
      apt-get update >/dev/null
      apt-get install php$PHP php$PHP-bcmath php$PHP-json php$PHP-mbstring php$PHP-common php$PHP-xml php$PHP-curl php$PHP-gd php$PHP-zip php$PHP-mysql php$PHP-sqlite -y
      sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
      sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
      systemctl restart apache2
    fi
    if [[ "$VERSION_ID" == "11" ]]; then
      # not available right now
      echo "deb https://packages.sury.org/php/ bullseye main" | tee /etc/apt/sources.list.d/php.list
      apt-get update >/dev/null
      apt-get install php$PHP php$PHP-bcmath php$PHP-json php$PHP-mbstring php$PHP-common php$PHP-xml php$PHP-curl php$PHP-gd php$PHP-zip php$PHP-mysql php$PHP-sqlite -y
      sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
      sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
      systemctl restart apache2
    fi
    if [[ "$VERSION_ID" == "16.04" ]]; then
      add-apt-repository -y ppa:ondrej/php
      apt-get update >/dev/null
      apt-get install php$PHP php$PHP-bcmath php$PHP-json php$PHP-mbstring php$PHP-common php$PHP-xml php$PHP-curl php$PHP-gd php$PHP-zip php$PHP-mysql php$PHP-sqlite -y
      sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
      sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
      systemctl restart apache2
    fi
    if [[ "$VERSION_ID" == "18.04" ]]; then
      add-apt-repository -y ppa:ondrej/php
      apt-get update >/dev/null
      apt-get install php$PHP php$PHP-bcmath php$PHP-json php$PHP-mbstring php$PHP-common php$PHP-xml php$PHP-curl php$PHP-gd php$PHP-zip php$PHP-mysql php$PHP-sqlite -y
      sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
      sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
      systemctl restart apache2
    fi
    if [[ "$VERSION_ID" == "20.04" ]]; then
      add-apt-repository -y ppa:ondrej/php
      apt-get update >/dev/null
      apt-get install php$PHP php$PHP-bcmath php$PHP-json php$PHP-mbstring php$PHP-common php$PHP-xml php$PHP-curl php$PHP-gd php$PHP-zip php$PHP-mysql php$PHP-sqlite -y
      sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
      sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
      systemctl restart apache2
    fi
  fi
}

function aptinstall_phpmyadmin() {
  echo "phpMyAdmin Installation"
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    mkdir /usr/share/phpmyadmin/ || exit
    cd /usr/share/phpmyadmin/ || exit
    wget https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMIN_VER/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz
    tar xzf phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz
    mv phpMyAdmin-$PHPMYADMIN_VER-all-languages/* /usr/share/phpmyadmin
    rm /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz
    rm -rf /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMIN_VER-all-languages
    # Create TempDir
    mkdir /usr/share/phpmyadmin/tmp || exit
    chown www-data:www-data /usr/share/phpmyadmin/tmp
    chmod 700 /usr/share/phpmyadmin/tmp
    randomBlowfishSecret=$(openssl rand -base64 32)
    sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" config.sample.inc.php >config.inc.php
    wget https://raw.githubusercontent.com/MaximeMichaud/mineweb-install/master/conf/phpmyadmin.conf
    ln -s /usr/share/phpmyadmin /var/www/phpmyadmin
    mv phpmyadmin.conf /etc/apache2/sites-available/
    a2ensite phpmyadmin
    systemctl restart apache2
  elif [[ "$OS" =~ (centos|amzn) ]]; then
    echo "No Support"
  elif [[ "$OS" == "fedora" ]]; then
    echo "No Support"
  fi
}

function install_azuriom() {
  rm -rf /var/www/html/
  mkdir /var/www/html
  cd /var/www/html || exit
  wget https://github.com/Azuriom/Azuriom/releases/download/v$AZURIOM_VER/Azuriom-$AZURIOM_VER.zip
  unzip -q Azuriom-$AZURIOM_VER.zip
  rm -rf Azuriom-$AZURIOM_VER.zip
  chmod -R 770 storage bootstrap/cache resources/themes plugins
  chown -R www-data:www-data /var/www/html
}

function install_composer() {
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer
  chmod +x /usr/local/bin/composer
}

function apt-apache2_cloudflare() {
  apt-get update >/dev/null
  cd /root/ || exit
  apt-get install libtool apache2-dev
  wget https://www.cloudflare.com/static/misc/mod_cloudflare/mod_cloudflare.c
  apxs -a -i -c mod_cloudflare.c
  apxs2 -a -i -c mod_cloudflare.c
  systemctl restart apache2
}

function autoUpdate() {
  echo "Enable Automatic Updates..."
  apt-get install -y unattended-upgrades
}

function setupdone() {
  IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
  echo "It done!"
  echo "Azuriom: http://$IP/"
  echo "phpMyAdmin: http://$IP/phpmyadmin"
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
    install_azuriom
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
  rm -rf /usr/share/phpmyadmin/
  mkdir /usr/share/phpmyadmin/
  cd /usr/share/phpmyadmin/ || exit
  wget https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMIN_VER/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz
  tar xzf phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz
  mv phpMyAdmin-$PHPMYADMIN_VER-all-languages/* /usr/share/phpmyadmin
  rm /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz
  rm -rf /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMIN_VER-all-languages
  # Create TempDir
  mkdir /usr/share/phpmyadmin/tmp || exit
  chown www-data:www-data /usr/share/phpmyadmin/tmp
  chmod 700 /var/www/phpmyadmin/tmp
  randomBlowfishSecret=$(openssl rand -base64 32)
  sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" config.sample.inc.php >config.inc.php
}

initialCheck

if [[ -e /var/www/html/app/ ]]; then
  manageMenu
else
  script
fi
