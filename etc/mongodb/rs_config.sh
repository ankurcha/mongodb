#!/bin/bash
#################################
# 
# Script allowing you to configure and initialize replica-set.
#
# Script will
# - modify /etc/mongodb/mongod.conf by setting replSet parameter 
#   ! exiting replSet value will be overwritten !
# - restart MongoDB daemon in order to re-read modified config file
# - initialize replica set 
# - optionally add (if provided) seed servers to replica set configuration
#
# Copyright (c) 2010 Vanilladesk Ltd. http://www.vanilladesk.com
#
#################################

ERR_START=1
ERR_PARAMS=2
ERR_CONNECT=3

RS_NAME=$1
RS_SEED=$2

MONGO_DAEMON="/etc/init.d/mongod"
MONGO_CONF="/etc/mongodb/mongod.conf"
MONGO_WAIT="30s"

#--------------------------------------
function show_usage() {

  cat <<DELIM
Usage: rs_config.sh <name> [seed]
	
name     - replica-set name
seed     - comma delimited list of existing replica set nodes
           'localhost' will be used if not specified
		   
Example: rs_config.sh rs1 10.0.0.1,10.0.0.2
This will configure mongod be a node in replica set rs1 which is already
having two nodes: 10.0.0.1 and 10.0.0.2.
DELIM

}

#--------------------------------------

# replica-set name is required
if [ ! $RS_NAME ]; then
  echo "Error: Wrong parameters."
  show_usage
  exit $ERR_START
fi

# if replica set seed is not specified, localhost will be used
# assuming this is the first node of replica-set
[ $RS_SEED ] || RS_SEED="localhost"

if [ ! "`which sed`" ]; then
  echo "Error: 'sed' not found. Please, install 'sed' first."
  exit $ERR_START
fi

if [ ! "`which ruby`" ]; then
  echo "Error: 'ruby' not found. Please, install 'ruby' first."
  exit $ERR_START
fi

if [ ! -e "$MONGO_DAEMON" ]; then
  echo "Error: $MONGO_DAEMON not found. Is mongodb installed correctly?."
  exit $ERR_START
fi


#--------------------------------------

# modify /etc/mongodb/mongod.conf
file_to_modify="$MONGO_CONF"
echo "Adding replica-set to configuration file $MONGO_CONF"
sudo sed -i -e "/replSet[[:space:]]*=/creplSet = $RS_NAME" $file_to_modify
_exitcode=$?
if [ $_exitcode -ne 0 ]; then
  echo "Error ($_exitcode): Can not modify file $file_to_modify."
  exit $ERR_RUNTIME
fi

# stop mongodb server
sudo $MONGO_DAEMON stop

# start mongodb server
sudo $MONGO_DAEMON start

# wait 30 seconds for mongodb server to start 
# it takes some time in case replica-set is configured
echo "Waiting $MONGO_WAIT for MongoDB server to come online."
sleep $MONGO_WAIT

# initialize replica set
sudo mongo --quiet --eval "printjson(rs.initiate());" "admin"
_exitcode=$?
if [ $_exitcode -ne 0 ]; then
  echo "Error ($_exitcode): Can not initiatize replica set."
  echo "Here is current replica set status:"
  sudo mongo --eval "printjson(rs.status());" "admin"
  exit $ERR_RUNTIME
fi

echo "Waiting 5s for MongoDB server to initialize replica-set."
sleep 5s

# add seed nodes
_node="`echo $RS_SEED | cut --delimiter=, --fields=1`"
_n=1
while [ "$_node" ]; do
  echo "Adding replica set node: $_node"
  sudo mongo --quiet --eval "printjson(rs.add(\"$_node\"));" "admin"
  _exitcode=$?
  if [ $_exitcode -ne 0 ]; then
    echo " - failed ($_exitcode)"
  else
    echo " - added ($_exitcode)"
  fi
  
  let _n++
  _node="`echo $RS_SEED | cut --delimiter=, --fields=$_n`"
done

#---------------------------------------

echo "-----------------------------------------------------"
echo "MongoDB replica-set $RS_NAME should be configured."
echo "-----------------------------------------------------"
