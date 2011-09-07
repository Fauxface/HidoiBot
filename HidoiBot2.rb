# encoding:utf-8
# Ng Guoyou
# HidoiBot2.rb
# Starts bot threads and loads plugins. Also has code for console input.

require 'socket'
require 'openssl'
require 'rubygems'
require 'timeout'

BOT_VERSION = 'HidoiBot2 alpha'
BOT_STARTUP_TIME = Time.now

def taskManager
  # Multiple servers are NOT supported now, run multiple instances to make sure everything runs right.
  # However, if you really really really still want to do it, you can create more bot objects.

  # Load local config
  load 'cfg/mainConfig.rb'

  # Load server config
  #serverDetails = readServerDetails
  load 'cfg/ircServerConfig.rb'

  # Load core modules
  loadCoreModules

  # Create bot objects
  $bots = [IRC.new(@serverDetails)]
  $bot1 = $bots[0] # Clean this up

  #for serverdetails size
  #eval create bots
  #create array of bot names
  #dobotsmappings

  #$bots = [{'name' => 'bot1', 'details' => serverDetails}]

  # Create bots
  #$bots.each{ |name|
  #    eval('$' + name) = IRC.new(serverDetails)
  #    eval('$' + name + 'MainThread') = Thread.new{eval(name).main}
  #    eval('$' + name + 'TimerThread') = Thread.new{eval(name).timer}

  #}

  # Load bot plugins
  loadBotPlugins

  # WEBrick server
  startWebrickServer if $useWebrick == true

  # Create bot threads
  $bot1MainThread = Thread.new{$bot1.main}
  $bot1TimerThread = Thread.new{$bot1.timer}

  # Start bot threads
  $bot1MainThread.join
  $bot1TimerThread.join
rescue => e
  puts e
  puts e.backtrace
end

def startWebrickServer
  extend WebUI

  Thread.new do
    startWebrick(:DocumentRoot => 'public', :Port => $webrickServerPort)
  end
end

def readServerDetails
  load 'cfg/ircServerConfig.rb'
  return serverDetails
end

def loadCoreModules
  coreFolder = "core"
  Dir.foreach(coreFolder) { |coreFilename|
    if File.extname(coreFilename) == ".rb"
      puts "Loading core module: #{coreFilename}"
      load "#{coreFolder}/#{coreFilename}"
    end
  }
rescue => e
  puts e
  puts e.backtrace
end

def loadBotPlugins
  $loadSuccess = 0
  $loadFailure = 0
  $failedPlugins = Array.new
  $loadedPlugins = Array.new

  pluginsFolder = "botPlugins"
  coreModulesFolder = "#{pluginsFolder}\core"
  puts "Loading bot plugins..."

  Dir.foreach(pluginsFolder) { |botPluginFilename|
    if File.extname(botPluginFilename) == ".rb"
      begin
        load "#{pluginsFolder}/#{botPluginFilename}"

        # Plugin's filename should be the same as its class name
        # This is done to simplify things, as there is no easy way to extract the plugin's class name from inside the file
        botPluginName = botPluginFilename.gsub(/\.rb$/, '')
        eval("$#{botPluginName} = #{botPluginName}.new()")

        $loadSuccess += 1
        $loadedPlugins.push(botPluginName)
      rescue => e
        $loadFailure += 1
        $failedPlugins.push(botPluginFilename)
        puts "#{botPluginFilename} failed to load:"
        puts e
        puts e.backtrace
      rescue SyntaxError => e
        $loadFailure += 1
        $failedPlugins.push(botPluginFilename)
        puts "#{botPluginFilename} failed to load:"
        puts e
        puts e.backtrace
      end
    else
      if botPluginFilename != ".." && botPluginFilename != "." && botPluginFilename != 'inactive'
        puts "#{botPluginFilename} is not a recognised bot plugin file."
      end
    end
  }
  puts "Plugins loaded - Successful: #{$loadSuccess} Failed: #{$loadFailure}"
  puts "Failed to load:\n#{$failedPlugins.join("\n")}" if $failedPlugins.size > 0
rescue => e
  puts e
  puts e.backtrace
end

def consoleInput
  # To use this, type '/<$botName.method>' in the console
  if @console != true
    Thread.new do
      loop do
        @console = true
        consoleInput = nil

        while consoleInput == nil
          consoleInput = STDIN.gets.chomp
        end

        if consoleInput[0] == '/'
          consoleInput[0] = ''
          puts "Evaluating console input: #{consoleInput}"
          eval(consoleInput)
        end

        consoleInput = nil
      end
    end
  end
rescue => e
  puts e
  puts e.backtrace
  retry
end

def reload
  loadCoreModules
  loadBotPlugins
end

consoleInput
taskManager