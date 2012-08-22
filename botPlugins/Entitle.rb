# encoding: UTF-8
# Ng Guoyou
# Entitle.rb
# (Automatically) gets titles of URLs, with filters.

class Entitle < BotPlugin
  def initialize
    require 'nokogiri' # Gem
    require 'open-uri'

    # Default Persistent Settings
    @s = {
      'active' => true,
      'timeout' => 10,
      'trackedSites' => ['http.*youtube.com.[^ ]*', 'http.*google.com.[^ ]*']
    }

    @settingsFile = "entitle/settings.json"
    loadSettings

    # Authorisations
    @reqAdminAuth = 3
    @reqQueryAuth = 0

    # Strings
    @noModeMsg = "An invalid mode was given."
    @noSuchFilterMsg = "The given filter is currently not tracked."

    # Required plugin stuff
    name = self.class.name
    @hook = "entitle"
    processEvery = true
    help = "Usage: #{@hook} (query|on|off|status|filters|add|remove) <term>\nFunction: Returns titles of URLs which match a predefined filter. Filters are regular expressions."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    if m.processEvery && @s['active']
      reply = checkFilter(m)
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
    puts "Entitle: Getting title of #{url}"
    html = open(url) # Work around bad unicode encoding
    doc = Nokogiri::HTML(html.read)
    doc.encoding = 'utf-8'
    return doc.at_css("title").text.gsub(/ *\n */, " ").lstrip.rstrip
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