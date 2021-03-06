﻿# encoding: UTF-8
# Ng Guoyou
# EntitleReverseImage.rb
# (Automatically) gets titles of iamges, with filters.
# This is based off the Entitle plugin (Entitle.rb)

# For unsafe redirects http->https required for Google reverse image search by URL
# Monkey patch OpenURI

class EntitleReverseImage < BotPlugin
  def initialize
    require 'nokogiri' # Gem
    require 'open-uri'

    # Default Persistent Settings
    @s = {
      'active' => true,
      'timeout' => 10,
      'trackedSites' => ['http.*png', 'http.*gif', 'http.*jpg', 'http.*jpeg', 'http.*bmp'],
      'googleQueryString' => "https://www.google.com/searchbyimage?&image_url=",
      'guessSelector' => ".qb-bmqc",
      'userAgent' => "Mozilla/5.0 (Windows NT 6.0; rv:20.0) Gecko/20100101 Firefox/20.0"
    }

    @settingsFile = "entitleri/settings.json"
    loadSettings

    # Authorisations
    @reqAdminAuth = 3
    @reqQueryAuth = 0

    # Strings
    @noModeMsg = "An invalid mode was given."
    @noSuchFilterMsg = "The given filter is currently not tracked."

    # Required plugin stuff
    name = self.class.name
    @hook = "entitleri"
    processEvery = true
    help = "Usage: #{@hook} (query|on|off|status|filters|add|remove) <term>\nFunction: Returns Google's guess for titles of images which match a predefined filter. Filters are regular expressions."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    if m.processEvery && @s['active']
      checkFilter(m)
    elsif !m.processEvery
      case m.mode
      when 'on'
        @s['active'] = true if m.authR(@reqAdminAuth)
        saveSettings
        m.reply(getStatus)

      when 'off'
        @s['active'] = false if m.authR(@reqAdminAuth)
        saveSettings
        m.reply(getStatus)

      when 'status'
        m.reply(getStatus) if m.authR(@reqQueryAuth)

      when 'filters'
        m.reply(getFilters) if m.authR(@reqAdminAuth)

      when 'add'
        if m.authR(@reqAdminAuth)
          addFilter(m)
          m.reply(getStatus)
        end

      when 'remove'
        if m.authR(@reqAdminAuth)
          removeFilter(m)
          m.reply(getStatus)
        end

      when 'query'
        m.reply(getTitle(m.args[1])) if m.authR(@reqQueryAuth)

      else
        m.reply(@noModeMsg)
      end
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def checkFilter(m)
    tempMessage = String.new(m.message)

    @s['trackedSites'].each { |regex|
      results = tempMessage.scan(Regexp.new(regex))

      if !results.empty?
        results.each { |result|
          Thread.new do
            timeout(@s["timeout"]) do
              title = getTitle(result)
              m.reply(title) if title != nil
            end
          end

          # Remove matched URL to prevent double-counting
          tempMessage.gsub!(result, '')
        }
      end
    }
  end

  def getTitle(url)
    puts "EntitleRI: Getting best guess of #{url}"

    # Gets redirect by spoofing User-Agent
    html = open(@s["googleQueryString"] + url,
        "User-Agent" => @s["userAgent"],
        allow_unsafe_redirects: true)

    doc = Nokogiri::HTML(html.read)
    doc.encoding = 'utf-8'
    guess = doc.css(@s["guessSelector"]).inner_text

    return guess if guess
  end

  def getStatus
    return "Entitle is #{@s['active'] ? 'active' : 'inactive'}. Tracking #{@s['trackedSites'].size} filters."
  end

  def getFilters
    return @s["trackedSites"].join(", ")
  end

  def addFilter(m)
    @s['trackedSites'].push(m.args[1]) if !@s['trackedSites'].include?(m.args[1])
    saveSettings
  end

  def removeFilter(m)
    if @s['trackedSites'].include?(m.args[1])
      @s['trackedSites'].delete(m.args[1])
      saveSettings
    else
      m.reply(@noSuchFilterMsg)
    end
  end
end