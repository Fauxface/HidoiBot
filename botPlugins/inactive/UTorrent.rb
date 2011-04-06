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

    def main(data)
        @givenLevel = data["authLevel"]
        
        mode = arguments(data)[0]
        
        case mode
            when 'add'
                if checkAuth(@reqAddTorAuth)
                    url = arguments(data)[1]
                    return sayf(addTorrentURL(url))
                end
            when 'list'
                return sayf(torList)
            else
                return sayf("#{@noAuthMsg} or an unknown mode was specified.")
        end
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
    
    def addTorrentFile(file)
    
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