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
  # However, if you really really really still want to do it, you can create more bot objects.

  # Load local config
  botSettings = loadSettings('botConfig.json')

  # Load server config
  serverSettings = loadSettings('serverConfig.json')

  # Load auth config
  authSettings = loadSettings('authConfig.json')

  # Load core modules
  loadCoreModules

  # Create bot objects
  $bots = [IRC.new(serverSettings["servers"][0], botSettings, authSettings)]
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
  startWebrickServer(botSettings) if botSettings["useWebrick"]

  # For convenience and compatibility
  $botUrl = botSettings["botUrl"]

  # Create bot threads
  $bot1MainThread = Thread.new{$bot1.main}

  # Start bot threads
  $bot1MainThread.join
rescue => e
  handleError(e)
end

def startWebrickServer(botSettings)
  # Starts WEBrick with public as the root directory.

  extend WebUI

  Thread.new do
    startWebrick(:DocumentRoot => 'public', :Port => botSettings["webrickServerPort"])
  end
end

def loadSettings(file)
  # Loads persistent plugin settings.

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
  # Saves persistent plugin settings.

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

  $loadSuccess, $loadFailure = 0, 0
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

        $loadSuccess += 1
        $loadedPlugins.push(botPluginName)
      rescue => e
        $loadFailure += 1
        $failedPlugins.push(filename)
        puts "#{filename} failed to load:"
        handleError(e)
      rescue SyntaxError => e
        $loadFailure += 1
        $failedPlugins.push(filename)
        puts "#{filename} failed to load:"
        handleError(e)
      end
    else
      puts "#{filename} is not a recognised bot plugin file." if !(/(\.|\.\.|inactive|settings)/ === filename)
    end
  }

  puts "Plugins loaded - Successful: #{$loadSuccess} Failed: #{$loadFailure}"
  puts "Failed to load:\n#{$failedPlugins.join("\n")}" if $failedPlugins.size > 0
rescue => e
  handleError(e)
end

def consoleInput
  # Evaluates console input.
  # Usage: type '/<$botName.method>' in the console

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

consoleInput
taskManager