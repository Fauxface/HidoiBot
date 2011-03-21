class About < BotPlugin
    def initialize
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
                return sayf(about)
            when 'plugins'
                return sayf(plugins)
            else 
                return nil
        end
    rescue => e
        handleError(e)
        return nil
    end
    
    def about()
		if RbConfig::CONFIG['host_os'] == 'linux-gnu'
            # Only for Unix
			sysinfo = `uname -v` 
			sysinfo.gsub!("\n","")
			return "#{BOT_VERSION} running on Ruby #{RUBY_VERSION} (#{sysinfo} #{RUBY_PLATFORM}). Bot uptime: #{humaniseSeconds((Time.now - BOT_STARTUP_TIME).to_i)}"
		#elsif RbConfig::CONFIG['host_os'] == 'mingw32'
        elsif RbConfig::CONFIG['host_os'] == 'windows'
			# Only for Windows
            sysinfo = `env`
			sysinfo.gsub!(" ","")
			return "#{bold(BOT_VERSION)} running on Ruby #{RUBY_VERSION} (#{sysinfo} #{RUBY_PLATFORM}). Bot uptime: #{humaniseSeconds((Time.now - BOT_STARTUP_TIME).to_i)}"
		else
            puts RbConfig::CONFIG['host_os']
			return "#{bold(BOT_VERSION)} running on Ruby #{RUBY_VERSION} #{RbConfig::CONFIG['host_os']} (#{RUBY_PLATFORM}). Bot uptime: #{humaniseSeconds((Time.now - BOT_STARTUP_TIME).to_i)}"
		end
	end
    
    def plugins
        requiredAuth = 0
        
        if authCheck(requiredAuth)
            rs = "Plugins loaded - Successful: #{$loadSuccess} Failed: #{$loadFailure}"
            rs += "\nLoaded plugins: #{$loadedPlugins.join(", ")}" if $loadedPlugins.size > 0
            rs += "\nFailed to load: #{$failedPlugins.join(", ")}" if $failedPlugins.size > 0
            return rs
        end
    end
end