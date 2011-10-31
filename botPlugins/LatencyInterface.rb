# LatencyInterface.rb
# Ng Guoyou
# Provides an interface to display bot latency and refresh it.

class LatencyInterface < BotPlugin
  def initialize
    # Authorisations
    @reqLatencyAuth = 0
    @reqLatencyRefreshAuth = 3

    # Strings
    @noAuthMessage = 'You are not authorised for this.'

    # Required plugin stuff
    name = self.class.name
    @hook = "latency"
    processEvery = false
    help = "Usage: #{@hook} *(refresh)\nFunction: Returns bot latency, or refreshes it."
    super(name, @hook, processEvery, help)
  end

  def main(data)
    @givenLevel = data["authLevel"]
    mode = arguments(data)[0]

    case 
    when mode == "refresh"
      if authCheck(@reqLatencyRefreshAuth)
        data["origin"].pingServer
        return sayf('Latency refreshed.')
      else
        return sayf(@noAuthMessage)
      end
    else
      return authCheck(@reqLatencyAuth) ? 'say "#{@latencyms.to_i}ms"' : sayf(@noAuthMessage)
    end
  rescue => e
    handleError(e)
    return nil
  end
end