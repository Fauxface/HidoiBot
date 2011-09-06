# Ng Guoyou
# About.rb
# This plugin returns information on the bot and bot plugins.

class About < BotPlugin
  def initialize
    # Authorisations
    @requiredPluginsAuth = 0
    @requiredAboutAuth = 0
    
    # Strings
    @noPluginsAuthMsg = "You are not authorised for this."
    @noAboutAuthMsg = "You are not authorised for this."
    
    # Required plugin stuff
    name = self.class.name
    @hook = 'about'
    processEvery = false
    help = "Usage: #{@hook} *(plugins)\nFunction: Returns version information."
    super(name, @hook, processEvery, help)
  end

  def main(data)
    @givenLevel = data["authLevel"]
    mode = arguments(data)[0]

    case mode
    when nil
      return authCheck(@requiredAboutAuth) ? sayf(about) : sayf(@noAboutAuthMsg)
    when 'plugins'
      return authCheck(@requiredPluginsAuth) ? sayf(plugins) : sayf(@noPluginsAuthMsg)
    else
      return nil
    end
  rescue => e
    handleError(e)
    return nil
  end

  def about
    hostOS = RbConfig::CONFIG['host_os']
    
    if hostOS == 'linux-gnu'
      # Only for Unix
      sysinfo = `uname -v`
      sysinfo.gsub!("\n","")
      
      return "#{BOT_VERSION} running on Ruby #{RUBY_VERSION} (#{sysinfo} #{RUBY_PLATFORM}). Bot uptime: #{humaniseSeconds((Time.now - BOT_STARTUP_TIME).to_i)}"
    elsif hostOS == 'windows'
      # Only for Windows
      sysinfo = `env`
      sysinfo.gsub!(" ","")
      
      return "#{bold(BOT_VERSION)} running on Ruby #{RUBY_VERSION} (#{sysinfo} #{RUBY_PLATFORM}). Bot uptime: #{humaniseSeconds((Time.now - BOT_STARTUP_TIME).to_i)}"
    else      
      return "#{bold(BOT_VERSION)} running on Ruby #{RUBY_VERSION} #{RbConfig::CONFIG['host_os']} (#{RUBY_PLATFORM}). Bot uptime: #{humaniseSeconds((Time.now - BOT_STARTUP_TIME).to_i)}"
    end
  end

  def plugins
    rs = "Plugins loaded - Successful: #{$loadSuccess} Failed: #{$loadFailure}"
    rs += "\nLoaded plugins: #{$loadedPlugins.join(", ")}" if $loadedPlugins.size > 0
    rs += "\nFailed to load: #{$failedPlugins.join(", ")}" if $failedPlugins.size > 0
    
    return rs
  end
end