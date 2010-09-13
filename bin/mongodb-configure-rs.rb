#!/usr/ruby
#################################
# 
# This script makes MongoDB replica-set configuration easier.
# 
# This script depends on following gems:
# - optiflag
# - mongo
#
# Copyright (c) 2010 Vanilladesk Ltd. http://www.vanilladesk.com
#
# Repository: http://github.com/vanilladesk/reg2rep
#
#################################

ERR_START	= 1
ERR_PARAMS	= 2
ERR_REPO	= 3

begin
  require 'rubygems'
rescue LoadError => e
  STDERR.puts("Library 'rubygems' not found. Read http://docs.rubygems.org/read/chapter/3#page13 how to install it.")
  exit ERR_START
end

begin
  require 'logger'
rescue LoadError => e
  STDERR.puts("Library 'logger' not found.")
  exit ERR_START
end

begin
  require 'mongo'
rescue LoadError => e
  STDERR.puts("Library 'mongo' not found. Run \'gem install mongo\' and try again.")
  exit ERR_START
end

begin
  require 'optiflag'
rescue LoadError => e
  STDERR.puts("Library 'optiflag' not found.  Run \'gem install optiflag\' and try again.")
  exit ERR_START
end

include Mongo

#*********************************************
# Module for analyzing commandline parameters

module AnalyzeCmd extend OptiFlagSet

  optional_flag "db" do
    description "Database to initialize."
  end
  
  optional_flag "seed" do
    alternate_forms "s"
    description "Seed to be used for replica-set initialization."
  end 

  optional_flag "verbose" do
    alternate_forms "v"
    description "Verbose level. Default 4 - info."
    value_matches [ "verbose level should be <1..5>" , /^[1-5]$/ ]
  end

  optional_switch_flag "help"

  and_process!

end

#**************************************
def show_help
  puts "mongodb-configure-rs v"+VER+" - Configure replica-set - (c) 2010 Vanilladesk Ltd."
  puts ""
  puts "Usage: mongodb-configure-rs.sh --db <host:port> [options]" 
  puts ""
  puts "Options:"
  puts " --seed <list>      - Comma separated list of existing replica set members"
  puts "                      to become 'seed' for this node. Assuming node is primary"
  puts "                      if no seed specified."
  puts "                      Example: host1:port1,host2,host3,host4:port4"
  puts " --verbose <level>  - Verbose level. Default is 4."
  puts "                    1 - fatal errors"
  puts "                    2 - errors"
  puts "                    3 - warnings"
  puts "                    4 - info"
  puts "                    5 - debug"
  puts ""
end

#****************************************
class String

  def to_a
    # Conversion of a string to an array.
    # It is assumes that string is formatted as follows: 'key1:value1,key2,key3:value...'

    _a = []
    _s = self.dup
	
    _s.split(',').each{|ss| _a << ss.split(':')}
    
    _a

  end
  
end

#****************************************

class Mongo::Connection

  # Add new replica set member to existing replica set
  def add_rs_member(new_member)
    raise 'Expecting String as parameter.' if not new_member.kind_of? String

    # Read replica set configuration
    _cfg = self['local']['system.replset'].find_one
    raise 'Replica set configuration does not exist.' if _cfg.nil?

    _cfg['version'] += 1

    # Find highest _id
    _next_id = 0
    _cfg['members'].each {|h| _next_id = h['_id'] + 1 if _next_id <= h['_id']}

    # Add new member to configuration
    _cfg['members'] << {"_id" => _next_id, "host" => new_member}
    logger.debug("Adding replica set member: _id = #{_next_id}, host = #{new_member}") if not logger.nil?

    self['admin'].command({ :replSetReconfig => _cfg})

  end
  
end
  
#****************************************
  
def rs_member_add(rs_seed, new_rs_member)

  return 0 if rs_seed.nil?
  
  begin
    _conn = Connection.multi(rs_seed.to_a)
  rescue Exception => e
    STDOUT.puts(e.message)
  end
  _result = _conn.add_rs_member(new_rs_member)

  # result key 'ok' is 1 if everything went fine, and 0 if not
  _result['ok'] 

end

#****************************************

begin
  VER = '1.0.0'

  if ARGV.flags.help?
    show_help
    exit ERR_START
  end
  
  #---------------------------------

  _log = Logger.new(STDERR)

  _log.level = case ARGV.flags.verbose
    when '1' then Logger::FATAL
    when '2' then Logger::ERROR
    when '3' then Logger::WARNING
    when '4' then Logger::INFO
    when '5' then Logger::DEBUG
    else Logger::INFO
  end

  #---------------------------------
  
  if not ARGV.flags.db?
    _log.error("Database to be initialized not specified.")
	exit ERR_START
  end

  #---------------------------------
  
  _log.info("Configuring database #{ARGV.flags.db} as replica-set node.")
  _log.info("Using seed: #{ARGV.flags.seed}") if ARGV.flags.seed?

  _host = ARGV.flags.db.split(":")[0]  # take the host from host:port
  _port = ARGV.flags.db.split(":")[1]  # take port from host:port
  
  _conn = Mongo::Connection.new(_host,_port,:slave_ok =>true, :logger=>_log)
  
  begin # rescue
    i = 0
    
    begin # while
      i += 1
      sleep 5 if i > 1
    
      # initialization should be performed using 'admin' database
      result=_conn.db('admin').command({:replSetGetStatus=>1}, :check_response=>false)
	  raise 'Not possible to get replica-set status.' if result.nil?
    
      if not result['set'].nil? # replica set is configured and running
        _log.info("Replica set node is configured.")
    
      # not running in replica set mode
      elsif result['startupStatus'].nil?
        raise "E001: This database is not configured to run as replica set node.\nUse mongod --replSet <set> to start it as replica set node."
    
      # loading config - replSet specified, seed specified, primary reachable, trying to load config from primary
      elsif result['startupStatus'] == 1 
        _log.info("Adding this node as secondary replica-set node.")
        rs_member_add(ARGV.flags.seed, ARGV.flags.db)
    
      # loading config - replSet specified, seed specified, primary not-reachable, trying to load config from primary
      elsif result['startupStatus'] == 4 
        _log.debug("Attempt #{i}. No host from specified seed hosts is reachable.")
      
      # no config - replSet specified, no seed specified - assuming this is the first node
      elsif result['startupStatus'] == 3 
        _log.info("Initializing this node as primary replica-set node.")
        _conn.db('admin').command({:replSetInitiate=>:nil})
      
      # coming online - replSet specified, initialized, primary  
      elsif result['startupStatus'] == 6 
        _log.debug("Attempt #{i}. Replica set initialized - coming online.")
	  end 
    
    end while result['set'].nil? and i < 5
    
  rescue Exception => e
    _log.error(e.message)
    _log.error("Replica set node initiliazation failed.")

  end 
  
  # close connection to database being configured
  _conn.close

  # close logger
  _log.close
  
  if result['set'].nil?
    exit 1
  end

  exit 0
  
end

