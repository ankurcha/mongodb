#!/usr/ruby
#################################
# 
# This script makes MongoDB replica-set configuration easier.
# 
# This script depends on following gems:
# - right_aws
# - right_http_connection
# - optiflag
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
  STDERR.puts("Requires the rubygems. Read http://docs.rubygems.org/read/chapter/3#page13 how to install them.")
  exit ERR_START
end

begin
  require 'mongo'
rescue LoadError => e
  STDERR.puts("Requires the mongo. Run \'gem install mongo\' and try again.")
  exit ERR_START
end


begin
  require 'optiflag'
rescue LoadError => e
  STDERR.puts("Requires the optiflag.  Run \'gem install optiflag\' and try again.")
  exit ERR_START
end

include Mongo

#*********************************************
# Module for analyzing commandline parameters

module AnalyzeCmd extend OptiFlagSet

  flag "seed" do
    alternate_forms "s"
    description "Add an item with specified attributes to a domain."
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
  puts "configure_rs v"+VER+" - Configure replica-set - (c) 2010 Vanilladesk Ltd."
  puts ""
  puts "Usage: configure_rs --seed <seed-data>" 
  puts ""
  puts "Commands:"
  puts " --logfile        - Logfile. Default is STDERR."
  puts " --verbose        - Verbose level. Default is 4."
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

  # create hash containing commandline options, if there are any  

  if ARGV.flags.help?
    show_help
    exit ERR_START
  end

  _log = Logger.new(STDERR)

  _log.level = case _cfg.verbose
      when '1' then Logger::FATAL
      when '2' then Logger::ERROR
      when '3' then Logger::WARNING
      when '4' then Logger::INFO
      when '5' then Logger::DEBUG
      else Logger::INFO
  end

    # check configuration
    if _cfg.access_id.nil? || _cfg.address.nil? || _cfg.access_secret.nil?
      STDERR.puts "Error: Repository address and/or credentials are missing."
      exit ERR_PARAMS
    end
 
    # command 'add' specified?
    if ARGV.flags.add?
      # we expect domain, item and attributes to be specified
      if (not ARGV.flags.add.kind_of? Array) || ARGV.flags.add.length < 3
        STDERR.puts "Error: Arguments missing for command '--add'"
        exit ERR_PARAMS
      end
    end

    if not _cfg.log_file.nil?
      begin
        _log = Logger.new(_cfg.log_file)
      rescue
        STDERR.puts "Error: Not possible to create/open log file #{_cfg.log_file}"
        exit ERR_PARAMS
      end
    end
	
	#---------------------------------
	
    _log.info("******** reg2rep #{VER} started")

    # command 'add' specified?
    if ARGV.flags.add?
      _result = _repo.add(ARGV.flags.add[0], ARGV.flags.add[1], ARGV.flags.add[2].to_h)
	  STDOUT.puts("Item #{ARGV.flags.add[1]} added to domain #{ARGV.flags.add[0]}")	if _cfg.verbose == 5
    end

	connection = Mongo::Connection.new("localhost",27017,:slave_ok =>true, :logger=>_log)
  db = connection.db("admin")
  result=db.command({:replSetGetStatus=>1})
  if not result['set'].nil? # replica set is configured and running
  elsif result['startupStatus'].nil? # not running in replica set mode
    STDOUT.puts("Error: This database is not configured to run as replica set node.\nUse mongod --replSet <set> to start it as replica set node.")
    exit ERR_NOT_RS_NODE
  elsif result['startupStatus'] == 1 # loading config - replSet specified, seed specified, primary reachable, trying to load config from primary
    STDOUT.puts("Adding this node as replica-set node.")
  elsif result['startupStatus'] == 4 # loading config - replSet specified, seed specified, primary not-reachable, trying to load config from primary
    
  elsif result['startupStatus'] == 3 # no config - replSet specified, no seed specified
  elsif result['startupStatus'] == 6 # coming online - replSet specified, initialized, primary
  
    
  
  if result['ok'] == 0 # replica set is not configured at all
  

  puts "#{result}"

    _log.close
	
  end
end

