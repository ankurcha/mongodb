#!/usr/ruby
#################################
# 
# Script allowing you to connect newly created
# replica-set node to existing replica-set.
# 
# This script depends on following gems:
# - optiflag
# - mongo
#
# Copyright (c) 2010 Vanilladesk Ltd. http://www.vanilladesk.com
#
#################################

APP_NAME	= 'rs_initiate'
ERR_START	= 1
ERR_PARAMS	= 2

begin
  require 'rubygems'
rescue LoadError => e
  STDERR.puts("Gem rubygems is required.  Run \'gem install rubygems\' and try again.")
  exit ERR_START
end

begin
  require 'mongo'
rescue LoadError => e
  STDERR.puts("Gem mongo is required.  Run \'gem install mongo\' and try again.")
  exit ERR_START
end

begin
  require 'optiflag'
rescue LoadError => e
  STDERR.puts("Gem optiflag is required.  Run \'gem install optiflag\' and try again.")
  exit ERR_START
end

include Mongo

def show_usage
  STDOUT.puts "#{APP_NAME} (c) 2010 Vanilladesk Ltd."
  STDOUT.puts "Usage: #{APP_NAME} <replica-set-members>"
  STDOUT.puts ""
  STDOUT.puts "<replica-set-members> is a comma delimited list of replica-set nodes."
  STDOUT.puts "Nodes can be represented using domain name or ip address."
  STDOUT.puts "There should be no spaces in the list."
  STDOUT.puts ""
  STDOUT.puts "Example: #{APP_NAME} db1.company.com,db2.company.com"
  STDOUT.puts ""
end

rs_members = []

if ARGV.empty?
  stdin_line = gets
  if not stdin_line
    show_usage
    exit ERR_START
  else
    while stdin_line
      rs_members << stdin_line
      stdin_line = gets
    end
  end
else
  rs_members=ARGV[0].split(',')  
end

# -------------------------
# create replica set configuration
rs_config = {}

rs_config = { :_id => 

# connect to the local server 'admin' database - this one is always available
db = Connection.new.db('admin')
db.command("command"=>{:replSetInitiate => rs_config})

# add all received replica-set nodes to replica-set configuration
# http://www.mongodb.org/display/DOCS/Adding+a+New+Set+Member
rs_members.each { |m| rs.add(m) }

db.close
