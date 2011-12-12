# LatencyInterface.rb
# Ng Guoyou
# Provides an interface to display bot latency and refresh it.

class LatencyInterface < BotPlugin
  def initialize
    # Authorisations
    @reqLatencyAuth = 0
    @reqLatencyRefreshAuth = 3

    # Required plugin stuff
    name = self.class.name
    @hook = "latency"
    processEvery = false
    help = "Usage: #{@hook} *(refresh)\nFunction: Returns bot latency, or refreshes it."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    if m.mode == "refresh"
      if m.authR(@reqLatencyRefreshAuth)
        m.origin.pingServer
        m.reply('Latency refreshed.')
      end
    elsif m.authR(@reqLatencyAuth)
      m.origin.say("#{m.origin.latencyms.to_i}ms")
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end
end