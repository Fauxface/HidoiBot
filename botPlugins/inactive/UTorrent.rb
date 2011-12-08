#TODO: Handle redirects, handle actions
#uTorrent API address: http://forum.utorrent.com/viewtopic.php?id=25661

class UTorrent < BotPlugin
  require 'net/http'
  require 'uri'

  def initialize
    # uTorrent Addresses
    #@host = 127.0.0.1
    @host = "192.168.1.42"
    @port = "8081"
    @user = "admin"
    @pass = "hidoi"

    # uTorrent WEBUI API Stuff
    @uiAdd = "http://#{@ip}:#{@port}/gui/"
    @addTorAdd = "#{@uiAdd}?action=add-url&s=" # Affix torrent URL to end
    @addTorAct = "/gui/?action=add-url"
    @getTorList = "/gui/?list=1"

    # Authorisations
    @reqAddTorAuth = 3

    # Strings
    @noAuthMsg = "You are not authorised for this."

    # Required plugin stuff
    name = self.class.name
    @hook = "torrent"
    processEvery = false
    help = "Usage: #{@hook} (add|list)\nFunction: An #{bold('experimental')} uTorrent WebUI interface."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    case m.mode
    when 'add'
      if m.authR(@reqAddTorAuth)
        url = m.args[1]
        #s = fetch(url)
        #s = puts s
        #upload(s)
        #upload('a')
        #getRedirectURL(url)
        m.reply(addTorrentURL(url))
      end
    when 'list'
      m.reply(torList)
    else
      m.reply("#{@noAuthMsg} or an unknown mode was specified.")
    end

    return nil
  rescue => e
      handleError(e)
      return nil
  end

  def addTorrentURL(torrent)
    #puts fetch(torrent)
    puts "uTorrent - Adding Torrent: #{torrent}"

    #this fetches the redirected .torrent itself, need to get url instead
    #puts fetch(torrent)

    Net::HTTP.start(@host, @port) do |http|
      token = getToken

      req = Net::HTTP::Get.new("#{@addTorAct}&token=#{token}&s=#{torrent}")
      req.basic_auth @user, @pass
      res = http.request(req)
      #puts "Response: #{res.body}"

      if res == nil
        return "Could not add torrent: #{res}"
      else
        return "Torrent (probably) added."
      end
    end
  end

  # nope
  def addTorrentFile(file)
    puts "uTorrent - Adding Torrent File: #{file}"
    addFileString = "http://#{@ip}:#{@port}/gui/?action=add-file"

    Net::HTTP.start(@host, @port) do |http|
      token = getToken

      res = Net::HTTP.post_form(URI.parse("#{addFileString}&token=#{token}"),
      {'q' => 'ruby', 'max' => '50'})
    end
  end

  # didn't really work
  def upload(torrent)
    #torrent = 'a.torrent'
    token = getToken
    addFileAction = "http://#{@ip}:#{@port}/gui/?action=add-file"
    #`curl -F file=@#{torrent} -F username=#{@user} -F password=#{@pass} #{addFileAction}`
    `curl -F file=#{torrent} --user admin:hidoi http://192.168.1.42:8081/gui/?action=add-file&token=#{getToken}`

    puts 'uploadan'
  rescue => e
    puts e
    puts e.backtrace
  end

  def torList
    Net::HTTP.start(@host, @port) do |http|
      token = getToken
      req = Net::HTTP::Get.new("#{@getTorList}&token=#{token}")
      req.basic_auth @user, @pass
      res = http.request(req)
      puts res.body
    end
  end

  def actTorrent(action, hash)
    case action
    when 'start'
    when 'stop'
    when 'pause'
    when 'unpause'
    when 'forceStart'
    when 'recheck'
    when 'remove'
    when 'removeData'
    when 'setPrio'
    when 'queueBottom'
    when 'queueDown'
    when 'queueTop'
    when 'queueUp'
    else
      return nil
    end
  end

  def getToken
    # uTorrent requires a GUID to prevent attacks
    Net::HTTP.start(@host, @port) do |http|
      req = Net::HTTP::Get.new('/gui/token.html')
      req.basic_auth @user, @pass
      res = http.request(req)
      tokenFile = Nokogiri::HTML.parse(res.body)
      token = tokenFile.css('#token').text

      #puts "Token: #{token}"
      return token
    end
  end

  def getRedirectURL(url)
    open(url, "Referer" => "http://www.nyaa.eu/") do |resp|
      puts resp.base_uri.to_s
    end
  end

  def fetch(uri_str, limit = 10)
    # fetch is taken from rubydocs, this gets redirect urls
    # You should choose better exception.
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0

    response = Net::HTTP.get_response(URI.parse(uri_str))
    case response
    when Net::HTTPSuccess
      response
    when Net::HTTPRedirection
      fetch(response['location'], limit - 1)
    else
      response.error!
    end
  rescue
  end
end