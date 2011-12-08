# Ng Guoyou
# MpcSync.rb
# Syncs and listens for sync packets for Media Player Classic synchronisation
# TODO: Move addresses, listening port into persistent settings

class MpcSync < BotPlugin
  require 'net/http'
  require 'nokogiri' # gem
  require 'socket'
  require 'timeout'

  def initialize
    # Settings
    # Address of MPC's Web UI
    @mpcPlayerAddress = 'http://192.168.1.42:13579'
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
    @cockedMessage = 'Player cocked.'
    @decockedMessage = 'Player decocked.'
    @notEvenCockedMessage = "How am I to decock when you don't even have a cock up?"
    @isCockedMessage = 'Long and ready.'
    @isNotCockedMessage = 'Definitely not long and ready.'
    @syncingMessage = "Syncing in #{@syncDelay} seconds..."
    @cannotGetNpMessage = 'Could not obtain MPC information. Is MPC running with WebUI active?'
    @butCannotGetNpMessage = 'However, MPC is not running.'
    @playingMessage = 'Playing.'
    @errorCockingMessage = 'Error cocking.'
    @alreadyCockedMessage = 'Already cocked.'

    @listening = false

    # Required plugin stuff
    name = self.class.name
    @cockTrigger = "cock"
    @decockTrigger = "decock"
    @hook = ["mpc", @cockTrigger, @decockTrigger]
    processEvery = false
    help = "Usage: #{@hook[0]} (cock|decock|cockstatus|sync <hostname:port>, <hostname:port>), #{@hook[1]}\nFunction: To sync Media Player Classic playback between bots using MPC's WebUI."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    # Handle alternate hooks
    case m.trigger
    when @cockTrigger
      mode = 'cock'
    when @decockTrigger
      mode = 'decock'
    else
      mode = m.mode
    end

    # This bit handles normal hooks
    case mode
    when 'cock'
      if m.authR(@reqCockAuth)
        if @cocked == true
          # If already cocked
          m.reply(@alreadyCockedMessage)
          return nil
        end

        if mpcListen(m) == false
          # If failed to cock
          m.reply(@errorCockingMessage)
        else
          @cocked = true
          nowPlayingInfo = nowPlaying

          if nowPlayingInfo == @cannotGetNpMessage
            m.reply(@cockedMessage + ' ' + @butCannotGetNpMessage)
          else
            m.reply(@cockedMessage + ' ' + nowPlayingInfo)
          end
        end
      end

    when /(decock|uncock)/
      if m.authR(@reqCockAuth)
        @cocked = false
        m.reply(@decockedMessage)
      end

    when /(cockstatus|status)/
      m.reply(@cocked ? @isCockedMessage : @isNotCockedMessage) if m.authR(@reqCockAuth)

    when /(playing|np|nowplaying)/
      m.reply(nowPlaying) if m.authR(@reqNpAuth)

    when 'sync'
      if m.authR(@reqSyncAuth)
        connectionInfo = m.stripTrigger.gsub('sync ', '').split(',')
        syncPlayers(connectionInfo, m)
      end

    else
      m.reply(nowPlaying) if m.authR(@reqNpAuth)
    end

    return nil
  end

  def mpcListen(m)
    # So that the bot will not lock up while listening
    Thread.new do
      UDPSocket.open { |socket|
        socket.bind('0.0.0.0', @mpcListenPort)
        puts "MpcSync: Listening on port #{@mpcListenPort}"

        while @cocked && !$shutdown
          packet, sender = socket.recvfrom(10)

          if packet == 'GO!'
            Net::HTTP.post_form(URI.parse(@mpcCommandAddress.to_s), { 'wm_command' => '887' })
            m.reply(@playingMessage)
            @cocked = false
          end
        end
      }
    end

    return true # Successfully exited
  rescue => e
    handleError(e)
    @cocked = false
    return false
  end

  def syncPlayers(connectionInfo, m)
    puts "MpcSync: Syncing #{connectionInfo}"

    Thread.new do
      begin
        # `for i in @syncDelay..1 do` doesn't work?
        @syncDelay.downto(0) { |i|
          sleep(1)
          m.reply(i)
        }

        syncStartTime = Time.now

        connectionInfo.each { |info|
          info.gsub!(' ','')
          addr = info.split(':')[0]
          port = info.split(':')[1].to_i

          mpcSocket = UDPSocket.new
          mpcSocket.connect(addr, port)
          mpcSocket.send "GO!", 0
          mpcSocket.close
          puts "MpcSync: sent 'GO!' UDP packet: #{addr}:#{port}"
        }

        m.reply "Players synced with a disparity of #{decimalPlace((Time.now - syncStartTime).to_f * 1000, 3)}ms"
      rescue => e
        handleError(e)
      ensure
        mpcSocket.close
      end
    end
  rescue => e
    handleError(e)
  end

  def nowPlaying
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
