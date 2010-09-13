#!/bin/bash
# Simple helper script to start configure_rs.rb
if [ ! `which ruby` ]; then
  echo "Error: Ruby not installed or accessible in PATH."
  exit 1
fi

_install_path=/opt/vdsd-db

ruby $_install_path/mongodb-configure-rs.rb $@