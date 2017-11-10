#!/bin/bash -e

cd /usr/local/mysql
mkdir data
chown mysql:mysql data

mkdir /var/run/mysql
chown mysql:mysql /var/run/mysql

#sudo -u mysql /usr/local/mysql/scripts/mysql_install_db