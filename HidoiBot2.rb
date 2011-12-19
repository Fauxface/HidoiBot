# encoding:utf-8
# Ng Guoyou
# HidoiBot2.rb
# Starts bot threads and loads plugins. Also has code for console input.

require 'json'
require 'openssl'
require 'socket'
require 'timeout'
require 'rubygems'

BOT_VERSION = 'HidoiBot2.1'
BOT_STARTUP_TIME = Time.now

def taskManager
  # Multiple servers are NOT supported now, run multiple instances to make sure everything runs right.
  # Plugins are not written to handle threads yet!

  # Load local, server, auth config
  botSettings = loadSettings('botConfig.json')
  serverSettings = loadSettings('serverConfig.json')
  authSettings = loadSettings('authConfig.json')

  # Load core modules
  loadCoreModules

  # Create bot objects
  $bots = Array.new
  botThreads = Array.new

  serverSettings["servers"].each { |server|
    $bots.push(IRC.new(server, botSettings, authSettings)) if server["active"]
  }

  # Load bot plugins
  loadBotPlugins

  # Create the bot threads
  $bots.each { |bot|
    botThreads.push(Thread.new(bot.main))
  }

  # Start the bot threads
  botThreads.each { |thread|
    thread.join
  }

  # WEBrick server
  startWebrickServer(botSettings) if botSettings["useWebrick"]

  # For convenience and compatibility
  $botUrl = botSettings["botUrl"]
rescue => e
  handleError(e)
end

def startWebrickServer(botSettings)
  # Starts WEBrick with public as the root directory.
  #
  # Params:
  # +botSettings+:: Settings +Hash+ containing settings for WEBrick.

  extend WebUI

  Thread.new do
    startWebrick(:DocumentRoot => 'public', :Port => botSettings["webrickServerPort"])
  end
end

def loadSettings(file)
  # Loads bot settings.
  #
  # Params:
  # +file+:: Filename of file in cfg to load

  configPath = 'cfg'
  s = File.open("#{configPath}/#{file}", "a+") { |f|
    return JSON.parse(f.read)
  }

  return s
rescue => e
  handleError(e)
  return false
end

def saveSettings(file, settings)
  # Saves bot settings.
  #
  # Params:
  # +file+:: Filename of file in cfg to load

  configPath = 'cfg'
  File.open("#{configPath}/#{file}", "w") { |f|
    f.puts settings.to_json
  }

  return true
rescue => e
  handleError(e)
  return false
end

def loadCoreModules
  # Loads .rb files found in core.

  coreFolder = "core"
  Dir.foreach(coreFolder) { |filename|
    if File.extname(filename) == ".rb"
      puts "Loading core module: #{filename}"
      load "#{coreFolder}/#{filename}"
    end
  }
rescue => e
  handleError(e)
end

def loadBotPlugins
  # Loads .rb files found in botPlugin.

  $failedPlugins, $loadedPlugins = Array.new, Array.new
  $plugins = Hash.new

  pluginsFolder = "botPlugins"
  puts "Loading bot plugins..."

  Dir.foreach(pluginsFolder) { |filename|
    if File.extname(filename) == ".rb"
      begin
        load "#{pluginsFolder}/#{filename}"

        # Plugin's filename should be the same as its class name
        # This is done to simplify things, as there is no easy way to extract the plugin's class name from inside the file
        botPluginName = filename.gsub(/\.rb$/, '')
        $plugins[botPluginName] = Object.const_get(botPluginName).new
        $loadedPlugins.push(botPluginName)
      rescue Exception => e
        $failedPlugins.push(filename)
        puts "#{filename} failed to load:"
        handleError(e)
      end
    else
      puts "#{filename} is not a recognised bot plugin file." if !(/(\.|\.\.|inactive|settings)/ === filename)
    end
  }

  puts "Plugins loaded - Successful: #{$loadedPlugins.size} Failed: #{$failedPlugins.size}"
  puts "Failed to load:\n#{$failedPlugins.join("\n")}" if $failedPlugins.size > 0
rescue => e
  handleError(e)
end

def consoleInput
  # Evaluates console input.
  # Usage: type '/<$botName.method>' in the console

  Thread.new do
    loop do
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
rescue Exception => e
  handleError(e)
  retry
end

def reload
  loadCoreModules
  loadBotPlugins
end

def handleError(e)
  puts e
  puts e.backtrace
end

# Start the bot
consoleInput
taskManager