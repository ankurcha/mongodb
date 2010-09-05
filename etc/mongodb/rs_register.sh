#!/bin/bash
#----------------------------------------
# This is simple helper script to execute ruby script
# registering newly created replica-set node to existing 
# replica set.
#
# Copyright (c) 2010 Vanilladesk Ltd. http://www.vanilladesk.com
#----------------------------------------

if [ ! "`which ruby`" ]; then
  echo "Error: Ruby not installed."
  exit 1
fi

ruby /etc/mongodb/rs_register.rb $@