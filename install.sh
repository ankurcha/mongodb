#!/bin/bash
#############################################
#
# Installation script for MongoDB database server (http://www.mongodb.org).
#
# Script will download and install specified MongoDB version (see configuration part)
#
# Copyright (c) 2010 Vanilladesk Ltd., http://www.vanilladesk.com
# 
# Repository: https://github.com/vanilladesk/mongodb
#
#############################################

##### CONFIGURATION - TO BE MODIFIED IF NECESSARY
# MongoDB version to be used
mongo_version="1.6.2"

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
install_fld="/usr/local/lib"

# Bin folder in which mongodb symlinks will be created
bin_folder="/usr/local/bin"

orig_fld="$PWD"

#--------------------------------------------
# color codes

C_BLACK='\033[0;30m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[1;34m'
C_MAGENTA='\033[1;35m'
C_CYAN='\033[1;36m'
C_WHITE='\033[1;37m'
C_GRAY='\033[;37m'
C_DEFAULT='\E[0m'

#-------------------------------------------

function cecho ()  {
  # Description
  #   Colorized echo
  #
  # Parameters:
  #   $1 = message
  #   $2 = color
  
  message=${1:-""}   # Defaults to default message.
  color=${2:-$C_BLACK}           # Defaults to black, if not specified.
  
  echo -e "$color$message$C_DEFAULT"  
  
  return
} 

# ----------------------------------------

# this script should be run under ROOT account
if [ "$UID" -ne "0" ]; then
  cecho "Error: Script should be run under root user privileges." $C_RED
  exit $ERR_START
fi 

if [ ! "`which sed`" ]; then
  cecho "Error: 'sed' not found. Please, install 'sed' first." $C_RED
  exit $ERR_START
fi

if [ ! "`which sudo`" ]; then
  cecho "Error: 'sudo' not found. Please, install 'sudo' first." $C_RED
  exit $ERR_START
fi

if [ ! "`which wget`" ]; then
  cecho "Error: 'wget' not found. Please, install 'wget' first." $C_RED
  exit $ERR_START
fi

# ----------------------------------------

# create work folder in case it does not exist
[ -d $work_fld ] || sudo mkdir $work_fld

# test if we are able to write to work folder
sudo touch $work_fld/test
if [ $? -ne 0 ]; then
  cecho "Fatal error: can't open work folder $work_fld" $C_RED
  exit $ERR_PREPARE
fi

cd $work_fld

# remove install archive in case it does exist just to be sure it is correct
[ -e $mongo_tar ] && sudo rm $mongo_tar > /dev/null

# download archive
sudo wget $mongo_download
if [ $? -ne 0 ]; then
  cecho "Fatal error: can not download $mongo_download." $C_RED
  exit $ERR_PREPARE
fi

# extract original source archive to predefined folder
sudo tar xvzf $mongo_tar -C $install_fld
if [ $? -ne 0 ]; then
  cecho "Fatal error: can not extract archive $mongo_tar to folder $install_fld." $C_RED
  exit $ERR_PREPARE
fi

if [ ! -d $install_fld/${mongo_tar%.*} ]; then
  cecho "Fatal error: expected folder does not exist $install_fld/${mongo_tar%.*} ." $C_RED
  exit $ERR_PREPARE
fi

if [ ! -e "$install_fld/${mongo_tar%.*}/bin/mongod" ]; then
  cecho "Fatal error: mongod not found in $install_fld/${mongo_tar%.*}." $_CRED
  exit $ERR_PREPARE
fi

############################### Files should be already there ###############

# Create uninstall folder
[ -d $install_fld/.uninstall ] || sudo mkdir $install_fld/.uninstall

# Create system user for MongoDB
username="mongodb"
cecho "Creating system user '"$username"'" $C_GREEN
  
# Check if user does not exist already
if [ ! "`sed -n -e "/^$username:/p" /etc/passwd`" ]
then
  # If not, create new user
  sudo useradd --create-home $username
  if [ "$?" -ne "0" ]
  then 
    cecho "Fatal error: User '"$username"' creation failed." $C_RED
    exit $ERR_INSTALL
  else
    echo "User '"$username"' created."
	
	# and make note that user has been created
	sudo touch $install_fld/.uninstall/user_created
  fi
else
  echo "User '"$username"' already does exist."
fi 

cecho "Creating symlinks in $bin_folder..." $C_GREEN
# move existing files/symlinks to .uninstall folder
[ -d $install_fld/.uninstall/bin ] || sudo mkdir $install_fld/.uninstall/bin
for f in $install_fld/${mongo_tar%.*}/bin/*; do
  sudo mv $bin_folder/${f##/*/} $install_fld/.uninstall/bin > /dev/nul
done

# create new symlinks pointing to new folder
sudo cp -s  $install_fld/${mongo_tar%.*}/bin/* $bin_folder
if [ $? -ne 0 ]; then
  cecho "Fatal Error: Creation of symlinks failed." $C_RED
  exit $ERR_INSTALL
fi

# create folder for database files
cecho "Creating database folder '"$mongo_dbpath"'" $C_GREEN
[ -d $mongo_dbpath ] || sudo mkdir $mongo_dbpath
if [ $? -ne 0 ]; then
  cecho "Fatal Error: Not possible to create folder for database." $C_RED
  exit $ERR_INSTALL
fi

# change owner for database folder so mongodb daemons can access it
sudo chown $username:$username $mongo_dbpath

cecho "Copying additional configuration files necessary for MongoDB." $C_GREEN

# create folder for log files
[ -d "/var/log/mongodb" ] || sudo mkdir /var/log/mongodb

# and change log folder owner so mongodb daemons can access it
sudo chown $username:$username /var/log/mongodb

echo "Creating init.d script for MongoDB database server..."
# move existing init.d script to unistall folder
[ -d $install_fld/.uninstall/initd ] || sudo mkdir $install_fld/.uninstall/initd
sudo mv $orig_fld/etc/init.d/mongod $install_fld/.uninstall/initd > /dev/nul

# create new init.d script
sudo cp $orig_fld/etc/init.d/mongod /etc/init.d/mongod
if [ $? -ne 0 ]; then
  cecho "Fatal Error: MongoDB database server init.d script creation failed." $C_RED
  exit $ERR_INSTALL
fi

# make sure init.d script will be executable
sudo chmod +x /etc/init.d/mongod

# add configuration file
cecho "Copying base configuration file (keeping existing ones)..." $C_GREEN
[ -d /etc/mongodb ] || sudo mkdir /etc/mongodb
for f in $orig_fld/etc/mongodb/*; do
  [ -e /etc/mongodb/${f##/*/} || sudo cp $f /etc/mongodb
  if [ $? -ne 0 ]; then
    cecho "Error: Copying of configuration file $f failed." $C_RED
    exit $ERR_INSTALL
  fi
done

# configure log-rotate
cecho "Configuring logrotate..." $C_GREEN
[ -e /etc/logrotate.d/mongodb ] || sudo cp $orig_fld/etc/logrotate.d/mongodb /etc/logrotate.d
if [ $? -ne 0 ]; then
  cecho "Error: Copying of logrotate configuration files failed." $C_RED
  exit $ERR_INSTALL
fi

cd $orig_fld

# make MongoDB to start at server boot
cecho "Creating startup scripts..." $C_GREEN
sudo update-rc.d mongod defaults 80 20
if [ $? -ne 0 ]; then
  cecho "Fatal Error: Not able to create startup rc scripts for MongoDB." $C_RED
  exit $ERR_INSTALL
fi

#================================================

# clean-up
sudo rm -R $work_fld

echo "----------------------------------------"
echo "MongoDB $mongo_version has been successfully installed."
echo "You can start MongoDB by starting /etc/init.d/mongod start"
echo "----------------------------------------"


