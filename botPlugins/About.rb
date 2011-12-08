# Ng Guoyou
# About.rb
# This plugin returns information on the bot and bot plugins.

class About < BotPlugin
  def initialize
    # Authorisations
    @requiredPluginsAuth = 0
    @requiredAboutAuth = 0

    # Required plugin stuff
    name = self.class.name
    @hook = 'about'
    processEvery = false
    help = "Usage: #{@hook} *(plugins)\nFunction: Returns version information."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    case m.mode
    when nil
      m.reply(about) if m.authR(@requiredAboutAuth)
    when 'plugins'
      m.reply(plugins) if m.authR(@requiredPluginsAuth)
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def about
    hostOS = RbConfig::CONFIG['host_os']

    if hostOS == 'linux-gnu'
      # Only for Unix
      sysinfo = `uname -v`.gsub!("\n","")

      return "#{BOT_VERSION} running on Ruby #{RUBY_VERSION} (#{sysinfo} #{RUBY_PLATFORM}). Bot uptime: #{humaniseSeconds((Time.now - BOT_STARTUP_TIME).to_i)}"
    elsif hostOS == 'windows'
      # Only for Windows
      sysinfo = `env`.gsub!(" ","")

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