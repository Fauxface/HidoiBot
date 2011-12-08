# Ng Guoyou
# ImageSearch.rb
# This plugin handles the searching through of the image database, random image, and image information.

class ImageSearch < BotPlugin
  def initialize
    extend HidoiSQL
    hsqlInitialize

    raise 'No image database was found' if !checkImageTable

    # Strings
    @noModeMessage = "Invalid mode."

    # Authorisations
    @reqHashAuth = 0
    @reqUrlAuth = 0
    @reqRndImgAuth = 0
    @reqInfoAuth = 0

    # Hooks
    @recallHook = "recall"
    @imsHook = "ims"
    @rndimgHook = "rndimg"
    
    # Required plugin stuff
    name = self.class.name
    @hook = [@recallHook, @imsHook, @rndimgHook]
    processEvery = false
    help = "Usage: #{@hook} *(hash <hash>|url <url>|info <hash>)\nFunction: Searches through ImageScraper's image database for details. hash returns source URLs from a SHA256 hash, url returns images mirrored on ImageScraper's database. Append ' :nomirror' to imagelinks if you wish to prevent ImageScraper from scraping links."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    if m.trigger == @recallHook
      # Recall URL to give mirror
      mode = 'url'
      term = m.mode
    elsif m.trigger == @imsHook
      # Ims
      mode = m.mode
      term = m.args[1] # args[0] is the mode
    elsif m.trigger == @rndimgHook
      # Random image
      mode = 'rndimg'
    end

    case mode
    when 'hash'
      m.reply(recallUrlFromHash(term).join(', ')) if m.authR(@reqHashAuth)
    when 'url'
      m.reply(mirrify(recallHashFromUrl(term))) if m.authR(@notAuthorisedMessage)
    when 'info'
      m.reply(getHashDetails(term)) if m.authR(@notAuthorisedMessage)
    when 'rndimg'
      m.reply(mirrify(randomImage)) if m.authR(@notAuthorisedMessage)
    else
      m.reply(@noModeMessage)
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def mirrify(term)
    prepend = "#{$botUrl}#{$imageServeDirectoryFromPublic}/"
    postfix = ' :nomirror'

    if term.class == Array
      term.each { |item|
        item.insert(0, prepend)
        item.insert(item.size, postfix)
        item.insert(item.size, "\n")
      }

      return term.join(', ')
    elsif term.class == String
      term.insert(0, prepend)
      term.insert(term.size, postfix)

      return term
    elsif term == nil
      return "Image not found."
    end
  rescue => e
    handleError(e)
  end

  def randomImage
    puts 'ImageSearch: Pulling random image, returns hash.filetype'
    filename = sql("SELECT sha256, filetype FROM image ORDER BY Random() LIMIT 1")[0]
    hash = filename[0]
    filetype = filename[1]

    return "#{hash}.#{filetype}"
  end

  def sanitizeHash(hash)
    return hash.slice(/[0-F]+/i)
  end

  def sanitizeUrl(url)
    return url.slice(/^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_]*)?$/)
  end

  def getHashDetails(hash)
    puts 'ImageSearch: Getting image details for hash.'
    hash = sanitizeHash(hash)

    imageId = sql("SELECT rowid FROM image WHERE sha256='#{hash}'")[0][0]
    details = sql("SELECT * FROM source WHERE image_id='#{imageId}'")
    reposts = details.size

    postId, time, url, user, channel, context = Array.new, Array.new, Array.new, Array.new, Array.new, Array.new
    mirror = mirrify(recallHashFiletypeFromHash(hash))

    for i in 0..(details.size - 1)
      postId.push(details[i][0])
      time.push(Time.at(details[i][1]).utc)
      url.push(details[i][2])
      user.push(details[i][3])
      channel.push(details[i][4])
      context.push(details[i][5])
    end

    rs = "Details for: #{hash}\nTimes seen: #{reposts}.\nFirst posted by #{user.first} at #{time.first} in #{channel.first}"
    rs += "\nLast posted by #{user.last} at #{time.last} in #{channel.last}." if user.size > 1
    rs += "\nOriginal URLs: #{url.uniq.join(', ')}"
    rs += "\nMirror: #{mirror}"

    return rs
  end

  def recallHashFiletypeFromHash(hash)
    # Takes URL, returns hash.filetype
    puts 'ImageSearch: Recalling hash.filetype from hash.'
    hash = sanitizeHash(hash)
    filetype = sql("SELECT filetype FROM image WHERE sha256='#{hash}'")[0][0]
    rs = "#{hash}.#{filetype}"

    return rs
  end

  def recallUrlFromHash(hash)
    # Takes hash, returns source URLs
    puts 'ImageSearch: Recalling source URL from hash.'
    hash = sanitizeHash(hash)
    imageId = sql("SELECT rowid FROM image WHERE sha256='#{hash}'")[0][0]
    sourceUrls = sql("SELECT url FROM source WHERE image_id='#{imageId}'")[0]

    return sourceUrls
  end

  def recallHashFromUrl(url)
    # Takes URL, returns hash.filetype
    puts 'ImageSearch: Recalling hash.filetype from source URL.'
    url = sanitizeUrl(url)
    imageHashes = Array.new
    imageId = sql("SELECT image_id FROM source WHERE url='#{url}'")[0]

    # Case where the URLs are the same but images are different
    imageId.each{ |id|
      x = (sql("SELECT sha256, filetype FROM image WHERE rowid='#{id}'"))[0]
      filename = "#{x[0]}.#{x[1]}"

      if filename != "."
        imageHashes.push(filename)
      else
        return nil
      end
    }

    return imageHashes
  rescue
    return nil
  end

  def checkImageTable
    return silentSql("SELECT name FROM sqlite_master WHERE type='table' AND name='image'")[0] == nil ? false : true
  end
end