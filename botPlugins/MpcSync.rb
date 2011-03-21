# Go to mpcListen() below for the example on threading
class MpcSync < BotPlugin
    require 'net/http'
    require 'nokogiri' # gem
    require 'socket'
    require 'timeout'
    
    def initialize
        # Settings
        # Address of MPC's Web UI
        @mpcPlayerAddress = 'http://127.0.0.1:13579'
        @mpcCommandAddress = @mpcPlayerAddress + '/command.html'
        @mpcPlayingAddress = @mpcPlayerAddress + '/controls.html'
        
        # Listens for 'GO!' packet on this port
        @mpcListenPort = 15555
        
        # Delay in seconds before sync
        @syncDelay = 3
        
        # Is bot cocked on load
        @cocked = false        
        
        # Authorisations
        @reqCockAuth = 3
        @reqNpAuth = 3
        @reqSyncAuth = 0
        
        # Strings
        @notAuthorisedMessage = 'You are not authorised for this.'
        @cockedMessage = "File cocked."
        @decockedMessage = "File decocked."
        @notEvenCockedMessage = "How am I to decock when you don't even have a cock up?"
        @isCockedMessage = 'Long and ready.'
        @isNotCockedMessage = 'Definitely not long and ready.'
        @syncingMessage = "Syncing in #{@syncDelay} seconds..."
        @cannotGetNpMessage = 'Could not obtain MPC information. Is MPC running with WebUI active?'
        @playingMessage = 'Playing.'
        
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
        
        case mode
            when 'cock'
                # So that we do not call mpcListen again when cock is called multiple times
                requiredLevel = @reqCockAuth
                if authCheck(requiredLevel)
                    mpcListen if @cocked == false
                    @cocked = true
                    @cockedChannel = data["channel"]
                    return sayf(@cockedMessage)
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
                
            when 'cockstatus'
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
        mpcSocket = UDPSocket.open
        mpcSocket.bind('0.0.0.0', @mpcListenPort)
        
        # All loops should to be put in a new thread so that the bot will not wait for loop to complete
        # Unless, of course, that is the desired behaviour
        Thread.new do
            begin
                puts "MpcSync: Listening on port #{@mpcListenPort}"
                
                while @cocked == true do
                    packet, sender = mpcSocket.recvfrom(10)
                    
                    if packet == 'GO!'
                        Net::HTTP.post_form(URI.parse(@mpcCommandAddress.to_s), { 'wm_command' => '887' })
                        @cocked = false
                        
                        # $bot1 is a very bad way to do this
                        $bot1.sayTo(@cockedChannel, @playingMessage)
                        
                        # This is the ideal method, but HOW DO I DO THIS?
                        #return "sayTo(#{@cockedChannel}, 'Playing.')"
                    else
                        puts "Wrong packet received."
                    end
                end
            rescue => e
                handleError(e)
            ensure
                mpcSocket.close
            end
        end
    rescue => e
        handleError(e)
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
