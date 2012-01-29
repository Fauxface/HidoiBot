# Ng Guoyou
# ImageScraper.rb
# This plugin handles scraping of image links and its settings. It also generates last10.html on a successful save.

class ImageScraper < BotPlugin
  require 'digest/md5'
  require 'digest/sha2'
  require 'open-uri'
  require 'timeout'

  def initialize
    extend WebUI
    extend HidoiSQL
    hsqlInitialize

    # Default Persistent Settings
    @s = {
      'scraping' => true,
      'doGenerateLast' => true,
      'imageScrapeTimeout' => 90
    }

    @settingsFile = "imageScraper/settings.json"
    loadSettings

    # Settings
    @imageDirectory = 'public/i'
    $imageServeDirectoryFromPublic = 'i'

    # Strings
    @scrapeOnMessage = 'Image scraping is now on.'
    @scrapeOffMessage = 'Image scraping is now off.'
    @scrapingIsOnMessage = 'Image scraping is currently on.'
    @scrapingIsOffMessage = 'Image scraping is currently off.'

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

  def main(m)
    urls = urlDetection(m)
    mode = m.mode

    if m.trigger == @hook && m.processEvery != true
      # If called using hook
      requiredLevel = @reqAuthLevel

      if m.authR(requiredLevel)
        case m.mode
        when 'on'
          @s['scraping'] = true
          saveSettings
          m.reply(@scrapeOnMessage)
        when 'off'
          @s['scraping'] = false
          saveSettings
          m.reply(@scrapeOffMessage)
        when 'status'
          m.reply(getScrapeStatus)
        end
      end
    elsif urls != nil && m.processEvery == true
      # Scrape images if url detected
      urls['urls'].each { |url|
        imageScrape(url[0], m) if @s['scraping'] == true
      }
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def getScrapeStatus
    return "Image scraping: #{@s['scraping']}, Last few images page generation: #{@s['doGenerateLast']}"
  end

  def urlDetection(m)
    # Currently only does image urls
    case m.message
    when /(https?\:[\/|.|\w|\s|\:|~|\-|\%]*?\.(?:jpg|jpeg|gif|png|bmp)) :nomirror/
      # :nomirror after an image url to not save
      # one :nomirror stops scraping for the line even if there are other links
      type = nil
      puts "ImageScraper: Image detected, but not saved as requested."
    when /(https?\:[\/|.|\w|\s|\:|~]*?\.(?:jpg|gif|png|bmp))/
      urls = m.message.scan(/(https?\:[\/|.|\w|\s|\:|~|\-|\%]*?\.(?:jpg|jpeg|gif|png|bmp))/i)
      type = 'image'
      urls.each { |url|
        puts "ImageScraper: Image detected: #{url}"
      }
    else
      type = nil
    end

    if type != nil
      return {
        'urls' => urls,
        'type' => type }
    else
      return nil
  end
  rescue => e
    handleError(e)
  end

  def imageScrape(imgUrl, m)
    # Saves and inserts imgUrl into image database. Calls generateLast if required.
    temporaryFilename = "#{@imageDirectory}/temp_#{Time.now.to_i}"

    # IB's image-saving code; grab image from URL and save into a temporary file
    timeout(@s['imageScrapeTimeout']) do
      File.open(temporaryFilename, 'wb') { |ofh|
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
      sPoster = m.sender
      sTime = Time.now.to_i
      sChannel = m.channel
      sContext = m.message
      sFilesize = File.size(temporaryFilename)
      sFiletype = urlData[urlData.size - 1]
      sSHA256 = getSHA256(temporaryFilename)
      sMD5 = getMD5(temporaryFilename)

      # If there is no filename conflict, commit temporary file
      newFilename = "#{@imageDirectory}/#{sSHA256}.#{sFiletype}"

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
    generateLast if @s['doGenerateLast'] == true
  rescue Timeout::Error
    puts "ImageScraper: Unable to save image: Timeout (#{@imageScrapeTimeout}s)"
  rescue => e
    puts "ImageScraper: Unable to save image: #{e}"
  ensure
    File.delete(temporaryFilename) if File.file?(temporaryFilename) == true
  end

  # Change these to prepared statements
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

  def generateLast
    # Generates last10.html, a page containing the last 10 images scraped
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
end