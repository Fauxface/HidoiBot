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
# TODO: Whitelist/Blacklist, better authentication, better max message length, channel info

class IRC
  attr_accessor :hostname
  attr_accessor :serverGroup
  attr_accessor :port
  attr_accessor :ssl
  attr_accessor :defaultChannels
  attr_accessor :defaultNickname
  attr_accessor :nickname
  attr_accessor :nickserv
  attr_accessor :connected
  attr_accessor :timer
  attr_accessor :latencyms

  def initialize(serverInfo, botInfo, authInfo)
    puts "#{serverInfo["serverGroup"]}: Starting bot..."
    coreMapping # Core trigger mapping

    # Setup attr_accessors/variables
    setupBot(botInfo)
    setupServer(serverInfo)
    setupAuth(authInfo)

    connect
  end

  def setupBot(botInfo)
    # Initialises variables related to bot operation.
    #
    # Params:
    # +botInfo+:: A +Hash+ defined in cfg/botInfo.json containing bot settigns.

    # Plugin mapping
    @triggerMap = Hash.new
    @pluginMapping = Hash.new
    @pluginMapping["processEvery"] = Array.new
    @pluginHelp = Hash.new

    # Bot variables
    @trigger = botInfo["trigger"]
    @pingTimeout = botInfo["pingTimeout"]
    @pingInterval = botInfo["pingInterval"]
    @serverConnectTimeout = botInfo["serverConnectTimeout"]
    @serverReconnectDelay = botInfo["serverReconnectDelay"]
    @maxMessageLength = botInfo["maxMessageLength"] # TODO: Calculate this dynamically
    @messageSendDelay = botInfo["messageSendDelay"]
    # @channelInfo = Hash.new

    # Instance timer
    @timer = Timer.new
  end

  def setupServer(serverInfo)
    # Initialises variables related to server connection.
    #
    # Params:
    # +serverInfo+:: A +Hash+ defined in cfg/serverInfo.rb containing bot and server information.

    @serverGroup = serverInfo["serverGroup"]
    @hostname = serverInfo["hostname"]
    @port = serverInfo["port"]
    @ssl = serverInfo["ssl"]
    @defaultChannels = serverInfo["defaultChannels"]
    @defaultNickname = serverInfo["nickname"]
    @nickname = serverInfo["nickname"]
    @nickserv = serverInfo["nickserv"]
    @nickservPassword = serverInfo["nickservpw"]
  end

  def coreMapping
    # Hardcoded pre-defined/non-plugin triggers
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
    # Maps plugin hooks to plugins. Should be called by BotPlugin initialize methods.
    #
    # Params:
    # +hook+:: The trigger, essentially. Will be used by detectTrigger.
    # +botModuleName+:: The name of the related botModule.
    # +processEvery+:: A boolean of whether every PRIVMSG should be passed along to the plugin.

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
    # Adds plugin help information to help command. Should be called by BotPlugin initialize methods.
    #
    # Params:
    # +hook+:: Help string identifier. (~help <hook>)
    # +help+:: Help string for the hook.

    @pluginHelp["#{hook}"] = help
  end

  def getPluginHelp(m)
    # Retrieve plugin help command
    #
    # Params:
    # +m+:: A +Message+, probably passed along from checkCoreTriggerMap

    message = m.message
    message.gsub!(/^help ?/, '')
    hook = message.split(' ')[0]

    if hook != nil
      say @pluginHelp[hook] != nil ? @pluginHelp[hook] : "No help was found."
    else
      say "Triggers: #{@pluginMapping.keys.join(', ').gsub!('processEvery, ', '')}, #{@coreMapping.keys.join(', ')}."
      say "Use #{@trigger}help <trigger> for help on a specific trigger."
    end
  end

  def getLoadedPlugins
    # Retrieve statistics on loaded and failed plugins
    say "Loaded plugins: #{$loadedPlugins.join(', ')}."
    say "Failed plugins: #{$failedPlugins.join(', ')}." if $failedPlugins.size > 0
  end

  def connect
    # Connects to a server. Details of the server are variables in serverDetails and can be found in /cfg
    timeout(@serverConnectTimeout) do
      if @ssl
        puts "#{@serverGroup}: Using SSL."
        @connection = OpenSSL::SSL::SSLSocket.new(TCPSocket.new(@hostname, @port))
        @connection.connect
      else
        # Default to no SSL usage
        puts "#{@serverGroup}: Not using SSL."
        @connection = TCPSocket.new(@hostname, @port)
      end
    end

    @nickname = @defaultNickname
    registerConnection
    # Nickserv is handled in handleData

    @connected = true
  rescue => e
    puts "Unable to connect to server: #{e}\nRetrying..."
    sleep(@serverReconnectDelay)
    retry
  end

  def registerConnection
    # Registers a successful connection to an IRC server.
    # See RFC 1459 for details.
    send "NICK #{@nickname}"
    send "USER HidoiBot 0 * :Watashi wa kawaii desu."
  end

  def registerNickserv
    # Registers with NickServ if requested. The server has to support this for it to work.
    # Not in RFC 1459.
    send "NICKSERV IDENTIFY #{@nickservpw[0]}"
    send "NICKSERV RECOVER #{@nickname} #{@nickservpw[0]}"
    send "NICKSERV RELEASE #{@nickname} #{@nickservpw[0]}"
    send "NICK #{@nickname}"
    send "NICKSERV GHOST #{@nickname}"
  end

  def disconnect(*quitMessage)
    # Disconnects from the server, but does not stop running.
    #
    # Params:
    # +quitMessage+:: Optional quit message to send. Will be seen as "HidoiBot has quit (quitMessage)".

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
    # Reconnects to the server.
    puts "#{@serverGroup}: Reconnecting..."
    disconnect('Reconnecting')
    connect
  end

  def restart
    # Restarts the bot.
    puts "#{@serverGroup}: Restarting..."
    disconnect('Restarting')
    exec("ruby HidoiBot2.rb")
  end

  def quit
    # Shuts down the bot.
    puts "#{@serverGroup}: Quitting..."
    disconnect('Quitting')
    $shutdown = true
    Process.exit
  end

  def reload
    # Reload plugins and core modules.
    @pluginMapping["processEvery"] = Array.new
    super
    rs = "Reloaded."
    rs += " Failed to load #{$failedPlugins.size} plugins:\n#{$failedPlugins.join(", ")}\nCheck console for details." if $failedPlugins.size > 0
    say rs
  rescue => e
    handleError(e)
  end

  def pingServer
    # Pings the server.
    send "PING #{Time.now.to_f}"
    @timer.addEvent(@hostname, 'pingTimeout', Time.now + @pingTimeout, 'single', 0, self)
  end

  def startPingChecks
    # Sets up a recurring +Event+ for ping checks.
    @timer.addEvent(@hostname, 'pingCheck', Time.now, 'recurring', @pingInterval, self)
  end

  def stopPingChecks
    # Stops ping checks. Used when disconnecting.
    @timer.deleteEventType('pingCheck')
    @timer.deleteEventType('pingTimeout')
  end

  def main
    # Main loop.
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
    # Processes raw lines from the server, and returns a formatted +Message+.
    #
    # Params:
    # +data+: A raw line received from the server.

    rawData = data
    message = data.split(' :').last.chomp
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
    # Handles +Message+ logic.
    #
    # Params:
    # +m+:: A +Message+.

    case m.messageType
    when 'PING'
      handlePing(m)
    when 'PONG'
      handlePong(m)
    when 'PRIVMSG'
      # Handle private messages
      @replyChannel = ((m.channel == @nickname) ? m.sender : m.channel)
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
    # Handles a +Message+ of type PING. PINGs are received from the server.
    #
    # Params:
    # +m+:: A +Message+ of type PING.

    send "PONG #{m.sender} #{m.message}"
  end

  def handlePong(m)
    # Handles a +Message+ of type PONG. PONGs are received in response to our PING
    #
    # Params:
    # +m+:: A +Message+ of type PONG.

    @timer.deleteEventType('pingTimeout')
    @latencyms = (Time.now.to_f - m.message.to_f) * 1000
  end

  def handleProcessEvery(m)
    # This sends data to every plugin that requested to process every PRIVMSG received.
    # ProcessEvery will only pass along PRIVMSGs.
    #
    # Params:
    # +m+:: A +Message+ of type PRIVMSG.

    m = m.clone
    m.processEvery = true

    @pluginMapping["processEvery"].each{ |pluginName|
      runPlugin(pluginName, m)
    }
  end

  def ctcpDetection(m)
    # Checks if a +Message+ is a CTCP message, and gives appropriate replies to them.
    #
    # Params:
    # +m+:: +Message+ to check for CTCP messages.

    case m.message
    when /^[\x01]PING(\s.+)?[\x01]? ?$/i
      # CTCP PING
      puts "> CTCP PING from #{m.sender}"
      send "NOTICE #{m.sender} :\001PING#{$1}\001"
    when /^[\x01]VERSION[\x01]? ?$/i
      # CTCP VERSION
      puts "> CTCP VERSION from #{m.sender}"
      send "NOTICE #{m.sender} :\001VERSION #{BOT_VERSION} - Ruby #{RUBY_VERSION}\001"
    when /^[\x01]TIME[\x01]? ?$/i
      # CTCP TIME
      puts "> CTCP TIME from #{m.sender}"
      send "NOTICE #{m.sender} :\001TIME #{Time.now}\001"
    end
  end

  def triggerDetection(m)
    # Checks if a +Message+ has a trigger, and runs the corresponding botPlugin if there is one.
    # Authorisation checks are handled in plugins themselves
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
    # These are hardcoded in.
    #
    # Params:
    # +m+:: +Message+ passed along, used to obtain the hostname.
    # +trigger+:: Trigger to be checked to see if it is in the core trigger mapping.

    if @coreMapping[trigger] != nil && @coreMapping[trigger][0] != nil && @coreMapping[trigger][1] != nil
      if checkAuth(m.hostname) >= @coreMapping[trigger][1]
        return @coreMapping[trigger][0]
      elsif checkAuth(m.hostname) < @coreMapping[trigger][1]
        say "You are not authorised for this."
      end
    end

    return nil
  end

  def checkTriggerMap(trigger)
    # Plugin-defined triggers, authorisation checks are contained within plugins
    #
    # Params:
    # +trigger+:: +String+ to be checked against the current plugin mapping.

    if @pluginMapping[trigger] != nil
      return {
        "moduleName" => @pluginMapping[trigger],
        "takesArgument" => @pluginMapping["takesArgument"]
      }
    end

    return nil
  end

  def runPlugin(plugin, m)
    # Calls main method of plugin and passes +Message+ m to it.
    #
    # Params:
    # +plugin+:: The plugin to run.
    # +m+:: A +Message+.

    # $plugins[plugin].main(m)
    $runQueue.push({"plugin" => plugin, "m" => m})
  rescue SyntaxError => e
    say "#{plugin}: Syntax error: #{e}"
    handleError(e)
  rescue => e
    handleError(e)
  end

  def joinChannel(channel)
    # Joins a channel.
    #
    # Params:
    # +channel+:: Channel to join. Include the hex, ie. joinChannel("#channel")

    send "JOIN #{channel}"
  end

  def partChannel(channel)
    # Joins a channel.
    #
    # Params:
    # +channel+:: Channel to part. Include the hex, ie. joinChannel("#channel")

    send "PART #{channel}"
  end

  def joinDefaultChannels
    # Joins default channels as described in cfg
    puts "Joining default channels: #{@defaultChannels}"
    @defaultChannels.each { |channel|
      joinChannel(channel)
    }
  end

  def send(message)
    # Sends msg to the IRC server, raw.
    #
    # Params:
    # +msg+:: Will be converted to a string.

    puts "SEND: #{message}"
    @connection.puts message.to_s
  rescue => e
    handleError(e)
  end

  def say(message)
    # Replies to the last message received. Can reply to a user or channel.
    # This is a method for convenience.
    #
    # Params:
    # +message+:: Line to reply.

    sayTo(@replyChannel, message)
  end

  def sayTo(channel, message)
    # Sends a PRIVMSG to +channel+, and, using a ghetto technique, breaks up long lines
    # into several sends to attempt to stay below the 512 character limit.
    # Existing +\n+s will be taken to be a line break and a separate send.
    # See RFC 1459 S4.4.1  for details.
    #
    # Params:
    # +channel+:: Channel or person to send the PRIVMSG.
    # +message+:: What to send to the person. Will be converted to a string.

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
  # This is extremely bad security.

  def auth(m)
    # Checks and authenticates a hostname if a correct password is given.
    # Will reply indicating success or failure.
    # Multiple password per authentication level are acceptable.
    #
    # Params:
    # +m+:: A +Message+ to authenticate.

    hostname = m.hostname
    password = m.message.gsub(/^auth /, '')
    sha256 = Digest::SHA256.new
    password =  Digest::SHA256.digest(password)

    if @passwordList[password] != nil
      authLevel = @passwordList[password]
      @authUsers[hostname] = authLevel
      say "#{hostname} authenticated for authorisation level #{@authUsers[hostname]}."
    else
      say "Invalid password."
    end
  end

  def deauth(m)
    # Deauthenticates a hostname. Will reply indicating success or inability to deauthenticate.
    #
    # Params:
    # +m+:: Message from a user to deauth.

    if @authUsers[m.hostname] > 0
      @authUsers.delete(m.hostname)
      say "Deauthenticated."
    else
      say "You are not even authenticated."
    end
  end

  def checkAuth(hostname)
    # Returns the current auth level of a hostname.
    #
    # Params:
    # +hostname+:: A hostname to check.

    # A Level 0 is an unauth-ed, weak and sometimes Moe<3 user, just like Saten~
    return @authUsers[hostname] ? @authUsers[hostname] : 0
  end

  def setupAuth(authInfo)
    # Does auths described in cfg.
    # TODO: Whitelist and blacklist.
    #
    # Params:
    # +authInfo+:: A +Hash+ of passwords and whitelisted/blacklisted hostnames defined in cfg/authConfig.json

    @passwordList = authInfo["passwords"]
    @authUsers = Hash.new
  end

  def handleError(error)
    # Handles an +Exception+ by printing the message and its backtrace for debugging.
    #
    # Params:
    # +error+:: An +Exception+.

    puts error.message
    puts error.backtrace.join("\n")
  end
end