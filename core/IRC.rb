# encoding:utf-8
class IRC
    # *botInfo is optional for reload
    def initialize(*botInfo)
        puts 'Starting bot...'
        extend Timer
        
        # So reload doesn't reinitialize bad stuff
        if @connected != true
            timerInitialize
            
            load 'cfg/botConfig.rb'
            botSettings
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
        @shutdown = false
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
            "help" => ['getPluginHelp(data)', 0]
        }
    end
    
    def doPluginMapping(hook, botModuleName, processEvery)
        if processEvery == true
            # If plugin processes every PRIVMSG received from server
            if @pluginMapping["processEvery"].include?(botModuleName) == false
                # If plugin is not processEvery's list
                # Required for cases where plugin has processEvery == true and multiple hooks
                @pluginMapping["processEvery"][@pluginMapping["processEvery"].size] = botModuleName
            end
        end
        
        if hook != nil
            # If plugin is called when trigger is detected
            @pluginMapping["#{hook}"] = botModuleName
        end       
    end
    
    def doPluginHelp(hook, help)
        @pluginHelp["#{hook}"] = help
    end
    
    def getPluginHelp(data)
        message = data["message"]
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
                    @TCP = TCPSocket.new(@hostname, @port)
                    @connection = OpenSSL::SSL::SSLSocket.new(@TCP)
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
            send "QUIT #{quitMessage[0]}" if quitMessage[0] != nil
        rescue
            puts "Sending of QUIT failed."
        end
        
        stopPingChecks
        
        @connection.close if @connection != nil
        @TCP.close if @TCP.class == TCPSocket
        @connected = false
    end
    
    def reconnect
        disconnect('Reconnecting')
        connect
    end
    
    def restart
        disconnect('Restarting')
        exec("ruby HidoiBot2.rb")
    end
    
    def quit
        disconnect('Quitting')
        @shutdown = true
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
            # This is to force .gets to recheck every second so the bot will know when socket messes up
            timeout(1) do
                @s = @connection.gets
            end
            
            puts @s
            parsed = parseData(@s)
            handleData(parsed)
        end
    rescue Timeout::Error
        # This is just here to handle the timeout
        if @shutdown == false
            retry
        elsif @shutdown == true
            quit
        else
            raise "@shutdown is neither true nor false"
        end
    rescue => e
        # When it actually knows the socket is bad
        handleError(e)

        if @shutdown == false
            reconnect
            retry
        end
    end

    def parseData(data)
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
            sender = data[0].slice(/^:.+?!/).gsub(/[:!@]/, '')
            realname = data[0].slice(/!.*?@/).gsub(/[:!@]/, '')
            hostname = data[0].slice(/@.*?$/).gsub(/[!@]/, '')
            messageType = 'PRIVMSG'
            channel = data[2]
            authLevel = checkAuth(hostname)
        elsif /^\d+$/ === data[1]
            # If message type is numeric
            sender = data[0].delete(':')
            messageType = data[1]
            authLevel, realname, hostname, channel = nil
        end
        
        return {
            "sender" => sender,
            "realname" => realname,
            "hostname" => hostname,
            "messageType" => messageType,
            "channel" => channel,
            "message" => message,
            "authLevel" => authLevel,
            "time" => Time.now,
            "serverGroup" => @serverGroup
        }
        
        return parsedData
    end
    
    def handleData(data)
        case data["messageType"]
            when 'PING'
                handlePing(data)
            when 'PONG'
                handlePong(data)
            when 'PRIVMSG'
                # Handle private messages
                if data["channel"] == @nickname
                    @replyChannel = data["sender"]
                else
                    @replyChannel = data["channel"]
                end
                
                triggerDetection(data)
                handleProcessEvery(data)
                ctcpDetection(data)
                
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
    
    def handlePing(data)
        send "PONG #{data["sender"]} #{data["message"]}"
    end
    
    def handlePong(data)
        deleteEventType('pingTimeout')
        @latencyms = (Time.now.to_f - data["message"].to_f) * 1000
    end
    
    def handleProcessEvery(data)
        # This sends data to every plugin that requested to process every PRIVMSG received
        @pluginMapping["processEvery"].each{ |pluginName|
            data["trigger"] = 'processEvery'
            runPlugin(pluginName, data)        
        }
    end
    
    def ctcpDetection(data)
        case data["message"]
            when /^[\001]PING(\s.+)?[\001]$/i
                # CTCP PING
                puts "> CTCP PING from #{data["sender"]}"
                send "NOTICE #{data["sender"]} :\001PING#{$1}\001"
            when /^[\001]VERSION[\001]?$/i
                # CTCP VERSION
                puts "> CTCP VERSION from #{data["sender"]}"
                send "NOTICE #{data["sender"]} :\001VERSION #{BOT_VERSION} - Ruby #{RUBY_VERSION}\001"
            when /^[\001]TIME[\001]?$/i
                # CTCP TIME
                puts "> CTCP TIME from #{data["sender"]}"
                send "NOTICE #{data["sender"]} :\001TIME #{Time.now}\001"
        end
    end
    
    def triggerDetection(data)
        # Triggers are case-sensitive
        message = data["message"]
        
        if /^#{@trigger}/ === message || /^#{@nickname}: / === message
            message.slice!(/^#{@trigger}/)
            message.slice!(/^#{@nickname}: /)
            message = message.split(' ')
            
            trigger = message[0]
            pluginInfo = checkTriggerMap(trigger)
            coreToRun = checkCoreTriggerMap(data, trigger)
            
            if pluginInfo != nil
                pluginToRun = pluginInfo["moduleName"]
                pluginTakesArgs =  pluginInfo["takesArgument"]
            end           
            
            if coreToRun != nil
                puts "Core trigger detected: #{coreToRun}"
                data["trigger"] = trigger
                data["message"] = message.join(' ')
                eval(coreToRun)
            elsif pluginToRun != nil 
                puts "Plugin trigger detected: #{pluginToRun}"
                data["trigger"] = trigger
                data["message"] = message.join(' ')
                runPlugin(pluginToRun, data)
            else
                puts "triggerDetection: No mapping for #{message.chomp} was found."
            end
        end
    rescue => e
        handleError(e)
    end
    
    def checkCoreTriggerMap(data, trigger)
        # Core triggers
        hostname = data["hostname"]
        
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
        # Plugin-defined triggers
        if @pluginMapping[trigger] != nil
            return {
                "moduleName" => @pluginMapping[trigger],
                "takesArgument" => @pluginMapping["takesArgument"]
                }
        else
            return nil
        end
    end
    
    def runPlugin(plugin, data)
        if data != nil
            returnData = eval("$#{plugin}.main(data)")
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
        @defaultChannels.each{ |channel|
            joinChannel(channel)
        }
    end
    
    def send(data)
        puts "SEND: #{data}"
        @connection.puts data.to_s
    end
    
    def say(message)
        sayTo(@replyChannel, message)
    end
    
    def sayTo(channel, message)
        puts "SAY TO #{channel}: #{message}"
        
        message = message.to_s
        
        if message.length > @maxMessageLength
            for i in 1..((message.length/@maxMessageLength).floor)
                insertIndex = i * @maxMessageLength
                message.insert(insertIndex, "...\n")
            end
        end
        
        message.each_line("\n") { |s|
            @connection.puts "PRIVMSG #{channel} :#{s}"
            sleep(@messageSendDelay)
        }
    end

    # HidoiAuth(tm), ENTERPRISE QUALITY
    def auth(data)
        hostname = data["hostname"]
        password = data["message"].gsub(/^auth /, '')
        
        if @passwordList[password] != nil
            authLevel = @passwordList[password]
            @authUsers[hostname] = authLevel
            say "#{hostname} authenticated for authorisation level #{@authUsers[hostname]}."
        else
            say "Invalid password."
        end
    end
    
    def deauth(hostname)
        if @authUsers[hostname] > 0
            @authUsers.delete(hostname)
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
    
    # Error Handling
    def handleError(error)
        puts error.message
        puts error.backtrace.join("\n")
    end
end