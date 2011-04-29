class ImageScraper < BotPlugin
    require 'digest/md5'
    require 'digest/sha2'
    require 'open-uri'
    require 'timeout'

    def initialize
        extend WebUI
        extend HidoiSQL
        hsqlInitialize

        # Settings
        @imageDirectory = 'public/i'
        $imageServeDirectoryFromPublic = 'i'
        
        # Maximum amount of time allowed for image saving
        @imageScrapeTimeout = 90
        
        # Do we generate last10.html
        @doGenerateLast = true
        
        # Is image scraping on by default
        @scraping = true 
        
        # Strings
        @scrapeOnMessage = 'Image scraping is now on.'
        @scrapeOffMessage = 'Image scraping is now off.'
        @scrapingIsOnMessage = 'Image scraping is currently on.'
        @scrapingIsOffMessage = 'Image scraping is currently off.'
        @notAuthorisedMessage = 'You are not authorised for this.'
        
        # Authorisations
        # Auth level required to change scrape settings
        @reqAuthLevel = 3
        
        checkImageTables
        checkImageDirectory
        
        # Required plugin stuff
        name = self.class.name
        @hook = 'scrape'
        processEvery = true
        help = "Usage: #{@hook} (on|off|status)\nFunction: Changes image scraping setting."
        super(name, @hook, processEvery, help)
    end

    def main(data)
        @givenLevel = data["authLevel"]
        
        url = urlDetection(data)
        
        if data["trigger"] == @hook
            puts "ImageScraper: Not scraping image URL in trigger"
            url = nil
            mode = nil
            
        elsif data["trigger"] == @hook
            # If called using hook
            requiredLevel = @reqAuthLevel
            
            if checkAuth(requiredLevel)
                mode = arguments(data)[0]
            else
                return @notAuthorisedMessage
            end
            
        elsif url != nil && data["trigger"] == 'processEvery'
            # Scrape image if url detected
            imageScrape(url['url'], data) if @scraping == true
            mode = nil
        end
        
        case mode
            when 'on'
                @scraping = true
                return sayf(@scrapeOnMessage)
            when 'off'
                @scraping = false
                return sayf(@scrapeOffMessage)
            when 'status'
                return sayf(getScrapeStatus)
        end
           
        return nil
    rescue => e
        handleError(e)
        return nil
    end
    
    def getScrapeStatus
        if @scraping == true
            return @scrapingIsOnMessage
        elsif @scraping == false
            return @scrapingIsOffMessage        
        end
    end
    
    def urlDetection(data)
        # Currently only does image urls, can be expanded further if required
        case data["message"]
            when /^.*(http(s?)\:)([\/|.|\w|\s|\:|~]|-|%|'|&|=)*\.(?:jpg|gif|png|bmp) :nomirror.*$/
                # :nomirror after an image url to not save
                url = data["message"].slice(/(http(s?)\:)([\/|.|\w|\s|\:|~]|-)*\.(?:jpg|gif|png|bmp)/i)
                type = nil
                puts "ImageScraper: Image detected: #{url}, but not saved as requested."
            when /^.*(http(s?)\:)([\/|.|\w|\s|\:|~]|-)*\.(?:jpg|gif|png|bmp).*$/
                # This cannot detect or handle two images
                url = data["message"].slice(/(http(s?)\:)([\/|.|\w|\s|\:|~]|-)*\.(?:jpg|gif|png|bmp)/i)
                type = 'image'
                puts "ImageScraper: Image detected: #{url}"
            else
                type = nil
        end
        
        if type != nil
            return {
                'url' => url,
                'type' => type
            }
        else
            return nil
        end
    rescue => e
        handleError(e)
    end
    
    def imageScrape(imgUrl, data)
        temporaryFilename = "#{@imageDirectory}/temp_#{Time.now.to_i}"
        
        # IB's image-saving code
        timeout(@imageScrapeTimeout) do
            File.open(temporaryFilename, 'wb'){ |ofh|
                open(imgUrl) { |ifh|
                    ofh.write(ifh.read(4096)) while !ifh.eof?
                }
            }
        end
        
        # If file is 0 bytes, delete it
        if File.size?(temporaryFilename) == nil
            File.delete(temporaryFilename)
            sCorrupt = true
        else 
            # Else start extracting information
            urlData = imgUrl.split(/[\/.]/)
            imgName = urlData[urlData.size - 2]
            
            sCorrupt = false
            sUrl = imgUrl
            sPoster = data["sender"]
            sTime = Time.now.to_i
            sChannel = data["channel"]
            sContext = data["message"]
            sFilesize = File.size(temporaryFilename)
            sFiletype = urlData[urlData.size - 1]
            sSHA256 = getSHA256(temporaryFilename)
            sMD5 = getMD5(temporaryFilename)

            newFilename = "#{@imageDirectory}/#{sSHA256}.#{sFiletype}"
            
            # If there is no filename conflict, commit temporary file
            if File.size?(newFilename) == nil
                File.rename(temporaryFilename, newFilename)
            end
        end
        
        # Record image(link) in database
        # Make sure we don't rewrite for dupes - Find a better way to do this check?
        if silentSql("SELECT sha256 FROM image WHERE sha256 = \"#{sSHA256}\"")[0] == nil
            sActive = true
            duplicate = false
            recordImage(sActive, sCorrupt, sSHA256, sMD5, sFilesize, sFiletype)
        else
            # Duplicate found
            puts "ImageScraper: This image is a duplicate."
            File.delete(temporaryFilename)
            duplicate = true
        end
        
        # Record source for all image links
        sImageId = silentSql("SELECT rowid FROM image WHERE sha256 = \"#{sSHA256}\"")[0][0]
        recordSource(sImageId, sTime, sUrl, sPoster, sChannel, sContext)
        puts "ImageScraper: #{newFilename} successfully saved. Size: #{sFilesize/1024}kB" if duplicate == false
          
        # Generate last10.html
        generateLast if @doGenerateLast == true
    rescue Timeout::Error
        puts "ImageScraper: Unable to save image: Timeout (#{@imageScrapeTimeout}s)"
    rescue => e
        puts "ImageScraper: Unable to save image: #{e}"
        #handleError(e)
    ensure
        File.delete(temporaryFilename) if File.file?(temporaryFilename) == true
    end
    
    def recordImage(active, corrupt, sha256, md5, size, filetype)
        silentSql ("
            INSERT INTO image (
                active,
                corrupt,
                sha256,
                md5,
                size,
                filetype
            ) VALUES (
                '#{active}',
                '#{corrupt}',
                '#{sha256}',
                '#{md5}',
                '#{size}',
                '#{filetype}'
            )
        ")
    end
    
    def recordSource(imageId, time, url, poster, channel, context)
        silentSql ("
            INSERT INTO source (
                image_id,
                time,
                url,
                poster,
                channel,
                context
            ) VALUES (
                '#{imageId}',
                '#{time}',
                '#{url}',
                '#{poster}',
                '#{channel}',
                '#{context}'
            )
        ")
    end
    
    def generateLast()
			numberOfImages = 10
			filename = 'public/ims-web/last10.html'
			mkHead(filename, 'HidoiBot:ims - Last 10 Images', 'last10.css')
			urls = sql("SELECT sha256, filetype FROM image ORDER BY rowid DESC LIMIT #{numberOfImages}")
			mkBody(filename, "<span class=\"titletext\">HidoiBot:ims</span><div class=\"headertext\">Last Ten Images <span><a href='../../index.html'>(Back)</a></span></div><div id=\"outer\">")
		for i in 0..urls.size
            if urls[i] != nil
                mkBody(filename, "<div class=\"imgdiv\"><a href=\"../i/#{urls[i][0]}.#{urls[i][1]}\"><img src = \"../i/#{urls[i][0]}.#{urls[i][1]}\" class=\"images\"/></a></div>")
            end
		end
            mkBody(filename, '</div><br /><br /><div id="footer"><div><span class= "boticontext">HidoiBot. </span><span class= "flavourtext">Developed with assistance from <a href="http://yasashiisyndicate.org/">The Yasashii Syndicate</a>.</span></div></div>')
            mkEnd(filename)
            puts "ImageScraper: #{filename} generated."
    rescue => e
        puts e
	end
    
    def getSHA256(filename)
        return Digest::SHA256.file(filename).hexdigest
    end
    
    def getMD5(filename)
        return Digest::MD5.file(filename)
    end
    
    def checkImageDirectory
        if Dir[@imageDirectory] == nil
            puts "imageScraper: #{@imageDirectory} does not exist, creating..."
            mkdir(@imageDirectory)
            puts "imageScraper: #{@imageDirectory} created."
        end  
    rescue => e
        # Will raise a SystemCallError if directory cannot be created
        handleError(e)
    end
    
    def checkImageTables
        # Table image
        silentSql ('
            CREATE TABLE IF NOT EXISTS image (
              active boolean NOT NULL DEFAULT true,
              corrupt boolean NOT NULL DEFAULT false,
              sha256 character varying(64) NOT NULL,
              md5 character varying(32),
              size integer,
              filetype character varying(64),
              width integer,
              height integer
            )
        ')
    
        # Table source
        silentSql ('
            CREATE TABLE IF NOT EXISTS source
            (
              image_id integer NOT NULL,
              time timestamp with time zone NOT NULL,
              url text NOT NULL,
              poster text NOT NULL,
              channel text NOT NULL,
              context text
            )
        ')

        # Index source
        silentSql ('
            CREATE INDEX IF NOT EXISTS source_image_idx ON source (image_id DESC)
        ')
    end
    
    # Unused, jpeg considerd :complex:
    def getImageDimensions(filename)
        extension = File.ext?(filename)
        case extension
            when 'png'
                dimensions = IO.read(filename)[0x10..0x18].unpack('NN')
            when 'bmp'
                d = IO.read('image.bmp')[14..28]
                d[0] == 40 ? d[4..-1].unpack('LL') : d[4..8].unpack('SS')
            when 'gif'
                dimensions = IO.read('image.gif')[6..10].unpack('SS')
            when 'jpg'
            when 'jpeg'
        end
    end
    
    def getImageInfo(filename)
        # Get stuff like MIME, dimensions, size
    end
end