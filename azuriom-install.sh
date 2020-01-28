#!/bin/bash
#
# [Script d'installation automatique sur Linux pour Azorium]
#
# GitHub : https://github.com/MaximeMichaud/Azuriom-install
# URL : https://azuriom.com/
#
# Ce script est destiné à une installation rapide et facile :
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
    echo "Désolé, vous devez l'exécuter en tant que root"
    exit 1
  fi
  checkOS
}

# Define versions
PHPMYADMINS_VER=4.9.4
AZURIOM_VER=0.1.0

function checkOS() {
  if [[ -e /etc/debian_version ]]; then
    OS="debian"
    source /etc/os-release

    if [[ "$ID" == "debian" || "$ID" == "raspbian" ]]; then
      if [[ ! $VERSION_ID =~ (10) ]]; then
        echo "⚠️ ${alert}Votre version de Debian n'est pas supportée.${normal}"
        echo ""
        echo "However, if you're using Debian >= 9 or unstable/testing then you can continue."
        echo "Gardez à l'esprit que ce n'est supportée !${normal}"
        echo ""
        until [[ $CONTINUE =~ (y|n) ]]; do
          read -rp "Continuer? [y/n] : " -e CONTINUE
        done
        if [[ "$CONTINUE" == "n" ]]; then
          exit 1
        fi
      fi
    fi
  else
    echo "${alert}On dirait que vous n'exécutez pas ce script d'installation automatique sur une distribution Debian ayant Debian 9/10 ${normal}"
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
  install_composer
  autoUpdate
  setupdone

}
function installQuestions() {
  echo "${cyan}Bienvenue dans l'installation automatique pour Azuriom !"
  echo "https://github.com/MaximeMichaud/Azuriom-install"
  echo "Je dois vous poser quelques questions avant de commencer l'installation."
  echo "Vous pouvez laisser les options par défaut et appuyer simplement sur Entrée si cela vous convient."
  echo ""
  echo "${alert}Veuillez sélectionner pour MYSQL : Use Legacy Authentication Method${normal}"
  echo "${cyan}Quelle version de PHP ?"
  echo "${red}Rouge = Fin de vie ${yellow}| Jaune = Sécurité uniquement ${green}| Vert = Support & Sécurité"
  echo "${yellow}   1) PHP 7.2 "
  echo "${green}   2) PHP 7.3 "
  echo "   3) PHP 7.4 (recommandé) ${normal}${cyan}"
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
  echo "Nous sommes prêts à commencer l'installation."
  echo "You will be able to generate a client at the end of the installation."
  APPROVE_INSTALL=${APPROVE_INSTALL:-n}
  if [[ $APPROVE_INSTALL =~ n ]]; then
    read -n1 -r -p "Appuyez sur n'importe quelle touche pour continuer..."
  fi
}

function aptupdate() {
  apt-get update >/dev/null
  apt-get upgrade -y >/dev/null
}
function aptinstall() {
  apt-get -y install ca-certificates apt-transport-https dirmngr zip unzip sudo lsb-release gnupg2 openssl curl >/dev/null
  echo "Mise à jour de la date..."
  ntpdate pool.ntp.org >/dev/null
}

function aptinstall_apache2() {
  apt-get install -y apache2
  a2enmod rewrite
  wget http://mineweb.maximemichaud.me/000-default.conf
  mv 000-default.conf /etc/apache2/sites-available/
  rm -rf 000-default.conf
  service apache2 restart
}

function aptinstall_mysql() {
  echo "deb http://repo.mysql.com/apt/debian/ buster mysql-8.0" >/etc/apt/sources.list.d/mysql.list
  echo "deb-src http://repo.mysql.com/apt/debian/ buster mysql-8.0" >>/etc/apt/sources.list.d/mysql.list
  apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
  apt-get update >/dev/null
  apt-get install --allow-unauthenticated mysql-server mysql-client -y
  systemctl enable mysql && systemctl start mysql
}

function aptinstall_php() {
  wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
  echo "deb https://packages.sury.org/php/ buster main" | sudo tee /etc/apt/sources.list.d/php.list
  apt-get update >/dev/null
  apt-get install php$PHP libapache2-mod-php$PHP php$PHP-mysql php$PHP-curl php$PHP-json php$PHP-gd php$PHP-memcached php$PHP-intl php$PHP-sqlite3 php$PHP-gmp php$PHP-geoip php$PHP-mbstring php$PHP-xml php$PHP-zip -y
  sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 20M|' /etc/php/$PHP/apache2/php.ini
  sed -i 's|post_max_size = 8M|post_max_size = 20M|' /etc/php/$PHP/apache2/php.ini
}

function aptinstall_phpmyadmin() {
  mkdir /usr/share/phpmyadmin/
  cd /usr/share/phpmyadmin/
  wget https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMINS_VER/phpMyAdmin-$PHPMYADMINS_VER-all-languages.tar.gz
  tar xzf phpMyAdmin-$PHPMYADMINS_VER-all-languages.tar.gz
  mv phpMyAdmin-$PHPMYADMINS_VER-all-languages/* /usr/share/phpmyadmin
  rm /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMINS_VER-all-languages.tar.gz
  rm -rf /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMINS_VER-all-languages
  wget http://mineweb.maximemichaud.me/phpmyadmin.conf
  mv phpmyadmin.conf /etc/apache2/sites-available/
  mkdir /usr/share/phpmyadmin/tmp
  chmod 777 /usr/share/phpmyadmin/tmp
  randomBlowfishSecret=$(openssl rand -base64 32)
  sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" config.sample.inc.php >config.inc.php
  a2ensite phpmyadmin
  systemctl restart apache2
}

function install_azuriom() {
  rm -rf /var/www/html/
  mkdir /var/www/html
  cd /var/www/html
  wget https://github.com/Azuriom/Azuriom/archive/v$AZURIOM_VER.zip
  mv v$AZURIOM_VER.zip /var/www/
  cd /var/www/
  unzip -q v$AZURIOM_VER.zip
  rm -rf v$AZURIOM_VER.zip
  mv Azuriom-v$AZURIOM_VER /var/www/html
  chmod -R 777 /var/www/html
}

function install_composer() {
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer
  chmod +x /usr/local/bin/composer
}

function apt-apache2_cloudflare() {
  apt-get update >/dev/null
  cd /root/
  apt-get install libtool apache2-dev
  wget https://www.cloudflare.com/static/misc/mod_cloudflare/mod_cloudflare.c
  apxs -a -i -c mod_cloudflare.c
  apxs2 -a -i -c mod_cloudflare.c
  systemctl restart apache2
}

function autoUpdate() {
  echo "Activation des mises à jour automatique..."
  apt-get install -y unattended-upgrades
}

function setupdone() {
  echo "Yep, it done"
}
function manageMenu() {
  clear
  echo "Bienvenue dans l'installation automatique pour Azorium !"
  echo "https://github.com/MaximeMichaud/Azuriom-install"
  echo ""
  echo "Il semblerait que le Script a déjà été utilisé dans le passé."
  echo ""
  echo "Qu'est-ce que tu veux faire?"
  echo "   1) Relancer l'installation"
  echo "   2) Mettre à jour phpMyAdmin"
  echo "   3) Ajouter un certificat (https)"
  echo "   4) Mettre à jour le script"
  echo "   5) Quitter"
  until [[ "$MENU_OPTION" =~ ^[1-5]$ ]]; do
    read -rp "Sélectionner une option [1-5] : " MENU_OPTION
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
  wget https://raw.githubusercontent.com/MaximeMichaud/azorium-install/master/azorium-install.sh -O azorium-install.sh
  chmod +x azorium-install.sh
  echo ""
  echo "Mise à jour effectuée."
  sleep 2
  ./azorium-install.sh
  exit
}

function updatephpMyAdmin() {
  rm -rf /usr/share/phpmyadmin/
  mkdir /usr/share/phpmyadmin/
  cd /usr/share/phpmyadmin/
  wget https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMINS_VER/phpMyAdmin-$PHPMYADMINS_VER-all-languages.tar.gz
  tar xzf phpMyAdmin-$PHPMYADMINS_VER-all-languages.tar.gz
  mv phpMyAdmin-$PHPMYADMINS_VER-all-languages/* /usr/share/phpmyadmin
  rm /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMINS_VER-all-languages.tar.gz
  rm -rf /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMINS_VER-all-languages
  mkdir /usr/share/phpmyadmin/tmp
  chmod 777 /usr/share/phpmyadmin/tmp
  randomBlowfishSecret=$(openssl rand -base64 32)
  sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" config.sample.inc.php >config.inc.php
}

initialCheck

if [[ -e /var/www/html/app/ ]]; then
  manageMenu
else
  script
fi
