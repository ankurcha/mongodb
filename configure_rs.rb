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

begin
  VER = '1.0.0'

  # create hash containing commandline options, if there are any  

  begin
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
    _log.info("repository: #{_cfg.address}")
    _log.info("access id: #{_cfg.access_id}")
    _log.info("secret key: " + _cfg.access_secret.to_secret)
    _log.info("verbose: #{_cfg.verbose}")

    _repo = R2Repo.new(_cfg, _log)

    # command 'add' specified?
    if ARGV.flags.add?
      _result = _repo.add(ARGV.flags.add[0], ARGV.flags.add[1], ARGV.flags.add[2].to_h)
	  STDOUT.puts("Item #{ARGV.flags.add[1]} added to domain #{ARGV.flags.add[0]}")	if _cfg.verbose == 5
    end

	  connection   = Mongo::Connection.new("localhost",27017,:slave_ok =>true)

  puts "#{connection}"

  connection.database_names.each { |name| puts name }
  connection.database_info.each { |info| puts info.inspect}

  db=connection.db("admin")
  puts "#{db}"

  result=db.command({:replSetGetStatus=>1})

  puts "#{result}"

    _log.close
	
  end
end

