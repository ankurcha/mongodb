#!/bin/bash
#############################################
#
# Installation script for MongoDB database server (http://www.mongodb.org).
#
# Script will download and install specified MongoDB version (see configuration part)
#
# Copyright (c) 2010 Vanilladesk Ltd., jozef.sovcik@vanilladesk.com
# 
# Repository: https://github.com/vanilladesk/mongodb
#
#############################################

##### CONFIGURATION - TO BE MODIFIED IF NECESSARY
# MongoDB version to be used
mongo_version="1.6.1"

# MongoDB data path
mongo_dbpath="/var/lib/mongodb"

# URL to be used to download MongoDB archive
# Make sure the last character of URL is "/"
mongo_download="http://downloads.mongodb.org/linux/"

##### OTHER VARIABLES - TO BE KEPT AS THEY ARE

ERR_START=1
ERR_PREPARE=2
ERR_INSTALL=3

# MongoDB platform selection
# i686 = 32bit
# x86_64 = 64bit (default)

# let's try to find out if this is 32bit or 64bit
mongo_platform="$HOSTTYPE"

# Debian & Ubuntu show i486 for 32bit platform
[ "$mongo_platform" == "i486" ] && mongo_platform="i686"

# if unsure, assume it is 64bit
[ "$mongo_platform" != "i686" ] && [ "$mongo_platform" != "x86_64" ] && mongo_platform="x86_64"

# MongoDB archive file "tarball" name
mongo_tar="mongodb-linux-$mongo_platform-$mongo_version.tgz"

# concatenate URL with TAR name
mongo_download="$mongo_download$mongo_tar"

# working forlder for temporary files
work_fld="/var/tmp/mongo"

# Folder where Mongo will be installed locally
tar_install_fld="/usr/local/lib"

orig_fld="$PWD"

# ----------------------------------------

# this script should be run under ROOT account
if [ "$UID" -ne "0" ]; then
  echo "Error: Script should be run under root user privileges."
  exit $ERR_START
fi 

if [ ! "`which sed`" ]; then
  echo "Error: 'sed' not found. Please, install 'sed' first."
  exit $ERR_START
fi

if [ ! "`which sudo`" ]; then
  echo "Error: 'sudo' not found. Please, install 'sudo' first."
  exit $ERR_START
fi

if [ ! "`which wget`" ]; then
  echo "Error: 'wget' not found. Please, install 'wget' first."
  exit $ERR_START
fi

# ----------------------------------------

# create work folder in case it does not exist
[ -d $work_fld ] || sudo mkdir $work_fld

# test if we are able to write to work folder
sudo touch $work_fld/test
if [ $? -ne 0 ]; then
  echo "Fatal error: can't open work folder $work_fld"
  exit $ERR_PREPARE
fi

cd $work_fld

# remove install archive in case it does exist just to be sure it is correct
[ -e $mongo_tar ] && sudo rm $mongo_tar > /dev/null

# download archive
sudo wget $mongo_download
if [ $? -ne 0 ]; then
  echo "Fatal error: can not download $mongo_download."
  exit $ERR_PREPARE
fi

# extract original source archive to predefined folder
sudo tar xvzf $mongo_tar -C $tar_install_fld
if [ $? -ne 0 ]; then
  echo "Fatal error: can not extract archive $mongo_tar to folder $tar_install_fld."
  exit $ERR_PREPARE
fi

if [ ! -d $tar_install_fld/${mongo_tar%.*} ]; then
  echo "Fatal error: expected folder does not exist $tar_install_fld/${mongo_tar%.*} ."
  exit $ERR_PREPARE
fi

if [ ! -e "$tar_install_fld/${mongo_tar%.*}/bin/mongod" ]; then
  echo "Fatal error: mongod not found in $tar_install_fld/${mongo_tar%.*}."
  exit $ERR_PREPARE
fi

############################### Files should be already there ###############

# Create system user for MongoDB
username="mongodb"
echo "Creating system user '"$username"'" 
  
# Check if user does not exist already
if [ ! "`sed -n -e "/^$username:/p" /etc/passwd`" ]
then
  # If not, create new user
  sudo useradd --create-home $username
  if [ "$?" -ne "0" ]
  then 
    echo "Fatal error: User '"$username"' creation failed."
    exit $ERR_INSTALL
  else
    echo "User '"$username"' created."
  fi
else
  echo "User '"$username"' already does exist."
fi 

echo "Creating symlinks in /usr/local/bin..."
sudo cp -s  $tar_install_fld/${mongo_tar%.*}/bin/* /usr/local/bin
if [ $? -ne 0 ]; then
  echo "Fatal Error: Creation of symlinks failed."
  exit $ERR_INSTALL
fi

echo "Creating database folder '"$mongo_dbpath"'"
[ ! -d $mongo_dbpath ] && sudo mkdir $mongo_dbpath
if [ $? -ne 0 ]; then
  echo "Fatal Error: Not possible to create folder for database."
  exit $ERR_INSTALL
fi

sudo chown $username:$username $mongo_dbpath

echo "Copying additional configuration files necessary for MongoDB."

# create necessary folders
[ -d "/var/log/mongodb" ] && sudo rm -R /var/log/mongodb
[ -d "/var/log/mongodb" ] || sudo mkdir /var/log/mongodb

sudo chown $username:$username /var/log/mongodb

# create init.d script
echo "Creating init.d script for MongoDB database server..."
sudo cp $orig_fld/etc/init.d/mongod /etc/init.d/mongod
if [ $? -ne 0 ]; then
  echo "Fatal Error: MongoDB database server init.d script copying failed."
  exit $ERR_INSTALL
fi

# make sure init.d script will be executable
sudo chmod +x /etc/init.d/mongod

# add configuration file
echo "Copying base configuration file..."
[ -d /etc/mongodb ] || sudo mkdir /etc/mongodb
sudo cp -r $orig_fld/etc/mongodb/* /etc/mongodb
if [ $? -ne 0 ]; then
  echo "Fatal Error: Copying of configuration files failed."
  exit $ERR_INSTALL
fi

# configure log-rotate
echo "Configuring logrotate..."
sudo cp $orig_fld/etc/logrotate.d/mongodb /etc/logrotate.d
if [ $? -ne 0 ]; then
  echo "Fatal Error: Copying of logrotate configuration files failed."
  exit $ERR_INSTALL
fi

cd $orig_fld

# make MongoDB to start at server boot
echo "Creating startup scripts..."
sudo update-rc.d mongod defaults 80 20
if [ $? -ne 0 ]; then
  echo "Fatal Error: Not able to create startup rc scripts for MongoDB."
  exit $ERR_INSTALL
fi

#================================================

# clean-up
sudo rm -R $work_fld

echo "----------------------------------------"
echo "MongoDB $mongo_version has been successfully installed."
echo "You can start MongoDB by starting /etc/init.d/mongod start"
echo "----------------------------------------"


