# Go to mpcListen() below for the example on threading
class MpcSync < BotPlugin
    require 'net/http'
    require 'nokogiri' # gem
    require 'socket'
    require 'timeout'
    
    def initialize
        # Settings
        # Address of MPC's Web UI
        @mpcPlayerAddress = 'http://127.0.0.0:13579'
        @mpcCommandAddress = @mpcPlayerAddress + '/command.html'
        @mpcPlayingAddress = @mpcPlayerAddress + '/controls.html'
        
        # Listens for 'GO!' packet on this port
        @mpcListenPort = 15555
        
        # Delay in seconds before sync
        @syncDelay = 3
        
        # Is bot cocked on load
        @cocked = false
        
        # Automatically decocks after x seconds if no "GO!" packet was received
        @cockTimeout = 3600
        
        # Authorisations
        @reqCockAuth = 3
        @reqNpAuth = 3
        @reqSyncAuth = 0
        
        # Strings
        @notAuthorisedMessage = 'You are not authorised for this.'
        @cockedMessage = "Player cocked."
        @decockedMessage = "Player decocked."
        @notEvenCockedMessage = "How am I to decock when you don't even have a cock up?"
        @isCockedMessage = 'Long and ready.'
        @isNotCockedMessage = 'Definitely not long and ready.'
        @syncingMessage = "Syncing in #{@syncDelay} seconds..."
        @cannotGetNpMessage = 'Could not obtain MPC information. Is MPC running with WebUI active?'
        @butCannotGetNpMessage = 'However, MPC is not running.'
        @playingMessage = 'Playing.'
        @errorCockingMessage = 'Error cocking.'
        
        @listening = false
        
        # Required plugin stuff
        name = self.class.name
        @hook = ["mpc", "cock", "decock"]
        processEvery = false
        help = "Usage: #{@hook[0]} (cock|decock|cockstatus|sync <hostname:port>, <hostname:port>), #{@hook[1]}\nFunction: To sync Media Player Classic playback between bots using MPC's WebUI."
        super(name, @hook, processEvery, help)
    end
    
    def main(data)
        @givenLevel = data["authLevel"]
        
        # This bit handles alternate hooks
        if data["trigger"] == @hook[1]
            # If cock was the trigger, mode is set for COCKAGE
            mode = 'cock'
        elsif data["trigger"] == @hook[2]
            # If decock was the trigger, mode is set for UNCOCKAGE
            mode = 'decock'
        else
            # If mpc was the trigger
            mode = arguments(data)[0]
        end
        
        # This bit handles normal hooks
        case mode
        when 'cock'
            # So that we do not call mpcListen again when cock is called multiple times
            requiredLevel = @reqCockAuth
            if authCheck(requiredLevel)
                if @listening == false
                    if mpcListen == false
                        return sayf(@errorCockingMessage)
                    else
                        @cocked = true
                        @cockedChannel = data["channel"]
                        nowPlayingInfo = nowPlaying
                        
                        if nowPlayingInfo == @cannotGetNpMessage
                            return sayf(@cockedMessage + ' ' + @butCannotGetNpMessage)
                        else
                            return sayf(@cockedMessage + ' ' + nowPlayingInfo)
                        end
                    end
                end                   
            else
                return sayf(@notAuthorisedMessage)
            end
            
        when /(decock|uncock)/
            requiredLevel = @reqCockAuth
            if authCheck(requiredLevel)
                if @cocked == true
                    @cocked = false 
                    return sayf(@decockedMessage)
                else
                    return sayf(@notEvenCockedMessage)
                end
            else
                return sayf(@notAuthorisedMessage)
            end
            
        when /(cockstatus|status)/
            requiredLevel = @reqCockAuth
            if authCheck(requiredLevel)
                if @cocked == true
                    return sayf(@isCockedMessage)
                else
                    return sayf(@isNotCockedMessage)
                end
            else
                return sayf(@notAuthorisedMessage)
            end
            
        when /(playing|np|nowplaying)/
            requiredLevel = @reqNpAuth
            if authCheck(requiredLevel)
                return sayf(nowPlaying)
            else
                return sayf(@notAuthorisedMessage)
            end
            
        when 'sync'
            requiredLevel = @reqSyncAuth
            if authCheck(requiredLevel)
                connectionInfo = stripTrigger(data).gsub('sync ', '').split(',')
                syncPlayers(connectionInfo)
                return sayf(@syncingMessage)
            else
                return sayf(@notAuthorisedMessage)
            end
            
        else
            requiredLevel = @reqNpAuth
            if authCheck(requiredLevel)
                return sayf(nowPlaying)
            end
        end
    end
    
    def mpcListen()
        # So that the bot will not lock up while listening
        Thread.new do
            begin
                timeout(@cockTimeout) do
                    @listening = true
                    @mpcSocket = UDPSocket.open
                    @mpcSocket.bind('0.0.0.0', @mpcListenPort)
                    puts "MpcSync: Listening on port #{@mpcListenPort}"
                    
                    while @listening == true do
                        packet, sender = @mpcSocket.recvfrom(10)
                        
                        if packet == 'GO!'
                            Net::HTTP.post_form(URI.parse(@mpcCommandAddress.to_s), { 'wm_command' => '887' })
                            # $bot1 is a very bad way to do this
                            $bot1.sayTo(@cockedChannel, @playingMessage)
                            @listening = false
                            @mpcSocket.close
                        else
                            puts "Wrong packet received."
                        end
                    end
                end
            rescue Timeout::Error => e
                puts "MpcSync: Timeout on listen."
                handleError(e)
                
                return false
            ensure
                @cocked = false
                puts "MpcSync: Uncocked."
                @listening = false
                puts "MpcSync: Stopped listening."
                @mpcSocket.close
                puts "MpcSync: Socket - #{@mpcSocket}"
            end
        end
        
        return true # Successfully exited
    rescue => e
        handleError(e)
        @cocked = false
        
        return false
    end
    
    def syncPlayers(connectionInfo)
        puts "MpcSync: Syncing #{connectionInfo}"
        
        Thread.new do
            begin
                sleep(@syncDelay)
                syncStartTime = Time.now
                connectionInfo.each{ |info|
                    info.gsub!(' ','')
                    addr = info.split(':')[0]
                    port = info.split(':')[1].to_i

                    mpcSocket = UDPSocket.new
                    mpcSocket.connect(addr, port)
                    mpcSocket.send "GO!", 0
                    mpcSocket.close
                    puts "MpcSync: sent 'GO!' UDP packet: #{addr}:#{port}"
                }
                puts "MpcSync: Players synced with a disparity of #{(Time.now - syncStartTime).to_f * 1000}ms" # milliseconds
            rescue => e
                handleError(e)
            ensure
                mpcSocket.close
            end
        end
    rescue => e
        handleError(e)
    end
    
    def nowPlaying()
        doc = Nokogiri::HTML(open(@mpcPlayingAddress))
        filepath = doc.search('//td[@colspan="4"]/nobr/a[1]').inner_text
        filename = filepath.to_s.split('\\').last
        curTime = doc.search('//td[@id="time"]').inner_text
        length = doc.search('//td[@id="time"]/../td[3]').inner_text
        status = doc.xpath('//td[@colspan="4"]/../../tr[2]/td[1]').inner_text
        statusString = status.gsub(/\W/, '')
        statusString.gsub!('Status','')
        
        returnString = "#{statusString}: #{filename} [#{curTime}/#{length}]"
        
        return returnString
    rescue => e
        return @cannotGetNpMessage
    end
end
