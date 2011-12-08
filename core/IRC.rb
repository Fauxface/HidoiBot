# encoding:utf-8
# Ng Guoyou
# IRC.rb
# Main IRC class containing code for:
#   Connection
#   IRC RFC implementation
#   Main logic
#   Primitive authentication
#   Plugin mapping
#   Ping checks
#
# TODO: Improve loading of settings, perhaps using JSON

class IRC
  # *botInfo is optional for reload
  def initialize(*botInfo)
    puts 'Starting bot...'
    extend Timer

    # TODO: Ensure $bots array contains IRC objects, so plugins can map for every IRC object.

    # So reload doesn't reinitialize bad stuff
    if @connected != true
      timerInitialize
      configFile = 'cfg/botConfig.rb'
      load configFile
      botSettings # This implements the shoddy settings loading in configFile
      coreMapping
      botVariables
      serverSettings(botInfo[0])
      doDefaultAuth
      connect
    end
  end

  def botVariables
    @triggerMap = Hash.new
    @pluginMapping = Hash.new
    @pluginMapping["processEvery"] = Array.new
    @pluginHelp = Hash.new
    $shutdown = false
  end

  def serverSettings(botInfo)
    serverDetails(botInfo["serverGroup"], botInfo["hostname"], botInfo["port"], botInfo["ssl"], botInfo["defaultChannels"])
    botDetails(botInfo["nickname"], botInfo["nickserv"], botInfo["nickservpw"])
  end

  def serverDetails(serverGroup, hostname, port, ssl, defaultChannels)
    @serverGroup = serverGroup
    @hostname = hostname
    @port = port
    @ssl = ssl
    @defaultChannels = defaultChannels
  end

  def botDetails(nickname, nickserv, nickservPassword)
    @defaultNickname = nickname
    @nickname = nickname
    @nickserv = nickserv
    @nickservPassword = nickservPassword
  end

  def getBotInformation
    return {
      "hostname" => @hostname,
      "port" => @port,
      "ssl" => @ssl,
      "nickname" => @nickname,
      "nickserv" => @nickserv
    }
  end

  def coreMapping
    # Pre-defined/Non-plugin triggers
    # Try not to use this for mapping

    # "trigger" => ['eval(this)', auth level],
    @coreMapping = {
      "reconnect" => ['reconnect', 3],
      "quit" => ['quit', 3],
      "restart" => ['restart', 3],
      "reload" => ['reload', 3],
      "help" => ['getPluginHelp(m)', 0]
    }
  end

  def doPluginMapping(hook, botModuleName, processEvery)
    if processEvery == true && @pluginMapping["processEvery"].include?(botModuleName) == false
      # If plugin processes every PRIVMSG received from server
      # and if plugin is not already on processEvery's list
      # This is required for cases where plugin has processEvery == true and multiple hooks
      @pluginMapping["processEvery"][@pluginMapping["processEvery"].size] = botModuleName
    end

    if hook != nil
      # If plugin is called on trigger
      @pluginMapping["#{hook}"] = botModuleName
    end
  end

  def doPluginHelp(hook, help)
    @pluginHelp["#{hook}"] = help
  end

  def getPluginHelp(m)
    message = m.message
    message.gsub!(/^help ?/, '')
    hook = message.split(' ')[0]

    if hook != nil
      if @pluginHelp[hook] != nil
        say @pluginHelp[hook]
      else
        say "No help was found."
      end
    else
      say "Triggers: #{@pluginMapping.keys.join(', ').gsub!('processEvery, ', '')}, #{@coreMapping.keys.join(', ')}."
      say "Use #{@trigger}help <trigger> for help on a specific trigger."
    end
  end

  def getLoadedPlugins
    say "Loaded plugins: #{$loadedPlugins.join(', ')}."
    say "Failed plugins: #{$failedPlugins.join(', ')}." if $failedPlugins.size > 0
  end

  def connect
    if @ssl == false
      timeout(@serverConnectTimeout) do
        @connection = TCPSocket.new(@hostname, @port)
      end
      puts "Not using SSL."
    elsif @ssl == true
      timeout(@serverConnectTimeout) do
        @connection = OpenSSL::SSL::SSLSocket.new(TCPSocket.new(@hostname, @port))
        @connection.connect
      end
      puts "Using SSL."
    else
      raise "connectError: SSL usage not defined"
    end

    @nickname = @defaultNickname
    registerConnection
    # Nickserv is handled in handleData

    @connected = true
  rescue => e
    puts "Unable to connect to server: #{e}\nRetrying..."
    sleep(1)
    retry
  end

  def registerConnection
    send "NICK #{@nickname}"
    send "USER HidoiBot 0 * :Watashi wa kawaii desu."
  end

  def registerNickserv
    send "NICKSERV IDENTIFY #{@nickservpw[0]}"
    send "NICKSERV RECOVER #{@nickname} #{@nickservpw[0]}"
    send "NICKSERV RELEASE #{@nickname} #{@nickservpw[0]}"
    send "NICK #{@nickname}"
    send "NICKSERV GHOST #{@nickname}"
  end

  def disconnect(*quitMessage)
    begin
      @connection.puts "QUIT #{quitMessage[0]}" if quitMessage[0] != nil
    rescue
      puts "Sending of QUIT failed, continuing with disconnect"
    end

    begin
      @connection.close if @connection != nil
    rescue => e
      puts "Warning in disconnect: #{e}"
    end

    stopPingChecks
    @connected = false
  end

  def reconnect
    puts "Reconnecting..."
    disconnect('Reconnecting')
    connect
  end

  def restart
    puts "Restarting..."
    disconnect('Restarting')
    exec("ruby HidoiBot2.rb")
  end

  def quit
    puts "Quitting..."
    disconnect('Quitting')
    $shutdown = true
    Process.exit
  end

  def reload
    @pluginMapping["processEvery"] = Array.new
    super
    initialize
    rs = "Reloaded."
    rs += " Failed to load #{$failedPlugins.size} plugins:\n#{$failedPlugins.join(", ")}\nCheck console for details." if $failedPlugins.size > 0
    say rs
  rescue => e
    handleError(e)
  end

  def pingServer
    send "PING #{Time.now.to_f}"
    addEvent(@hostname, 'pingTimeout', Time.now + @pingTimeout, 'single', 0)
  end

  def startPingChecks
    addEvent(@hostname, 'pingCheck', Time.now, 'recurring', @pingInterval)
  end

  def stopPingChecks
    deleteEventType('pingCheck')
    deleteEventType('pingTimeout')
  end

  def main
    loop do
      # This is to force .gets to recheck every second so the bot will reconnect, and not hang, when socket messes up
      timeout(1) do
        @s = @connection.gets
      end

      puts @s
      parsed = parseData(@s)
      handleData(parsed)
    end
  rescue Timeout::Error
    # This is just here to handle the timeout
    $shutdown == false ? retry : quit
  rescue => e
    # When it actually knows the socket is bad
    handleError(e)

    if $shutdown == false
      reconnect
      retry
    end
  end

  def parseData(data)
    rawData = data
    message = data.split(' :')
    message = message[message.size - 1].chomp
    data = data.split(' ')

    if data[0] == 'PING'
      sender = data[1]
      messageType = 'PING'
      authLevel, realname, hostname, channel = nil
    elsif data[1] == 'PONG'
      sender = data[0]
      messageType = 'PONG'
      channel = data[2]
      authLevel, realname = nil
    elsif data[1] == 'PRIVMSG'
      data[0].slice(/^:(.+)!(.+)@(.+)/)
      sender = $1
      realname = $2
      hostname = $3
      messageType = 'PRIVMSG'
      channel = data[2]
      authLevel = checkAuth(hostname)
    elsif /^\d+$/ === data[1]
      # If message type is numeric
      sender = data[0].delete(':')
      messageType = data[1]
      authLevel, realname, hostname, channel = nil
    end

    m = Message.new
    m.sender = sender
    m.realname = realname
    m.hostname = hostname
    m.messageType = messageType
    m.channel = channel
    m.message = message
    m.rawMessage = rawData
    m.authLevel = authLevel
    m.serverGroup = @serverGroup
    m.originId = self.object_id
    m.origin = self

    return m
  end

  def handleData(m)
    case m.messageType
    when 'PING'
      handlePing(m)
    when 'PONG'
      handlePong(m)
    when 'PRIVMSG'
      # Handle private messages
      if m.channel == @nickname
        @replyChannel = m.sender
      else
        @replyChannel = m.channel
      end

      triggerDetection(m)
      handleProcessEvery(m)
      ctcpDetection(m)
    when '001'
      # When registered
      registerNickserv if @nickserv == 1
      joinDefaultChannels
      startPingChecks
    when '433'
      # When nickname is in use
      @nickname += '_'
      registerConnection
    #when '332'
      # Channel topic
    #when '333'
      # Channel topic details
    #when '353'
      # Channel users
    end
  end

  def handlePing(m)
    send "PONG #{m.sender} #{m.message}"
  end

  def handlePong(m)
    deleteEventType('pingTimeout')
    @latencyms = (Time.now.to_f - m.message.to_f) * 1000
  end

  def handleProcessEvery(m)
    # This sends data to every plugin that requested to process every PRIVMSG received
    @pluginMapping["processEvery"].each{ |pluginName|
      m.processEvery = true
      runPlugin(pluginName, m)
    }
  end

  def ctcpDetection(m)
      case m.message
      when /^[\001]PING(\s.+)?[\001]$/i
        # CTCP PING
        puts "> CTCP PING from #{m.sender}"
        send "NOTICE #{m.sender} :\001PING#{$1}\001"
      when /^[\001]VERSION[\001]?$/i
        # CTCP VERSION
        puts "> CTCP VERSION from #{m.sender}"
        send "NOTICE #{m.sender} :\001VERSION #{BOT_VERSION} - Ruby #{RUBY_VERSION}\001"
      when /^[\001]TIME[\001]?$/i
        # CTCP TIME
        puts "> CTCP TIME from #{m.sender}"
        send "NOTICE #{m.sender} :\001TIME #{Time.now}\001"
      end
  end

  def triggerDetection(m)
    # Triggers are case-insensitive (/./i)
    message = m.message

    if /^#{@trigger}/i === message || /^#{@nickname}: /i === message
      # Trigger via trigger character or nickname
      message.slice!(/^#{@trigger}/i)
      message.slice!(/^#{@nickname}: /i)
      message = message.split(' ')

      trigger = message[0]
      pluginInfo = checkTriggerMap(trigger)
      coreToRun = checkCoreTriggerMap(m, trigger)

      if pluginInfo != nil
        pluginToRun = pluginInfo["moduleName"]
        pluginTakesArgs =  pluginInfo["takesArgument"]
      end

      if coreToRun != nil
        puts "Core trigger detected: #{coreToRun}"
        m.trigger= trigger
        m.message = message.join(' ')
        eval(coreToRun)
      elsif pluginToRun != nil
        puts "Plugin trigger detected: #{pluginToRun}"
        m.trigger = trigger
        m.message = message.join(' ')
        runPlugin(pluginToRun, m)
      else
        puts "triggerDetection: No mapping for #{message} was found."
      end
    end
  rescue => e
    handleError(e)
  end

  def checkCoreTriggerMap(m, trigger)
    # Core triggers, checks which core trigger was called, with authorisation check
    hostname = m.hostname

    if @coreMapping[trigger] != nil
      if @coreMapping[trigger][0] != nil && checkAuth(hostname) >= @coreMapping[trigger][1]
        return @coreMapping[trigger][0]
      elsif @coreMapping[trigger][0] != nil && checkAuth(hostname) < @coreMapping[trigger][1]
        say "You are not authorised for that."
        return nil
      end
    else
      return nil
    end
  end

  def checkTriggerMap(trigger)
    # Plugin-defined triggers, authorisation checks are contained within plugins
    if @pluginMapping[trigger] != nil
      return {
        "moduleName" => @pluginMapping[trigger],
        "takesArgument" => @pluginMapping["takesArgument"]
      }
    else
      return nil
    end
  end

  def runPlugin(plugin, m)
    if m != nil
      runs = "$#{plugin}.main(m)"
      returnData = eval(runs)
    end

    eval(returnData) if returnData != nil
  rescue SyntaxError => e
    say "#{plugin}: Syntax error: #{e}"
    handleError(e)
  rescue => e
    handleError(e)
  end

  def joinChannel(channel)
    send "JOIN #{channel}"
  end

  def partChannel(channel)
    send "PART #{channel}"
  end

  def joinDefaultChannels
    puts "Joining default channels: #{@defaultChannels}"
    @defaultChannels.each { |channel|
      joinChannel(channel)
    }
  end

  def send(m)
    puts "SEND: #{m}"
    @connection.puts m.to_s
  rescue => e
    handleError(e)
  end

  def say(message)
    sayTo(@replyChannel, message)
  end

  def sayTo(channel, message)
    puts "SAY TO #{channel}: #{message}"
    message = message.to_s

    if message.length > @maxMessageLength
      for i in 1..((message.length/@maxMessageLength).floor)
        message.insert(i * @maxMessageLength, "...\n")
      end
    end

    message.each_line("\n") { |s|
      @connection.puts "PRIVMSG #{channel} :#{s}"
      sleep(@messageSendDelay)
    }
  end

  # HidoiAuth(tm), "ENTERPRISE QUALITY"
  # Authentication uses a user's hostname
  def auth(m)
    hostname = m.hostname
    password = m.message.gsub(/^auth /, '')

    if @passwordList[password] != nil
      authLevel = @passwordList[password]
      @authUsers[hostname] = authLevel
      say "#{hostname} authenticated for authorisation level #{@authUsers[hostname]}."
    else
      say "Invalid password."
    end
  end

  def deauth(m)
    if @authUsers[m.hostname] > 0
      @authUsers.delete(m.hostname)
      say "Deauthenticated."
    else
      say "You are not even authenticated."
    end
  end

  def checkAuth(hostname)
    if @authUsers[hostname]
      return @authUsers[hostname]
    else
      # A Level 0 is an unauth-ed, weak and sometimes Moe<3 user, just like Saten~
      return 0
    end
  end

  def doDefaultAuth
    load 'cfg/authConfig.rb'
    passwordList
    @authUsers = Hash.new
  end

  def handleError(error)
    puts error.message
    puts error.backtrace.join("\n")
  end
end
