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

#--------------------------------

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

#---------------------------------
# Read replica set members from commandline arguments or stdin
#
def read_rs_members
	_rs_members = []

	# no commandline arguments passed?
	if ARGV.empty? 
	
	  # try to read STDIN
	  _stdin_line = gets
	  
	  # stdin empty?
	  if not _stdin_line
	  
		show_usage
		exit ERR_START
		
	  else
	  
	    # read stdin - we are expecting replicaset members to be specified one per line
		while _stdin_line
		  _rs_members << _stdin_line
		  _stdin_line = gets
		end
		
	  end
	else
	  # if any arguments have been specified, we expect replicaset members
	  # to be specified in the first argument
	  _rs_members = ARGV[0].split(',')  
	end
	
	_rs_members
	
end

#---------------------------------------

begin

    # read replica set members from commadline or stdin
	rs_members = read_rs_members()
	
	# connect to the local server 'admin' database - this one is always available
        begin
	  conn = Connection.new('localhost', 27017)
	  #db = Mongo::Connection.new("localhost").db("admin")
        rescue Exception => e
          puts("Fatal Error: Connection to specified replica set node failed.")
          exit 2
        end
	
	puts("------DB: #{conn}")
	#db.each {|x| puts("++ #{x}")}
	
	# initiate replica set using default parameters
	rs_config = conn.db("admin").command( { :replSetGetStatus => 1 } )

	puts("-----CONF: #{rs_config}")
	rs_config.each {|x| puts("++ #{x}")}
	# read replica set name
	
	# add all received replica-set nodes to replica-set configuration
	# http://www.mongodb.org/display/DOCS/Adding+a+New+Set+Member
	#rs_members.each { |m| rs.add(m) }

	db.close
end
