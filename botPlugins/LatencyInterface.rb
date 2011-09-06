# Ng Guoyou
# LatencyInterface.rb
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

    return mode == 'refresh' && authCheck(@reqLatencyRefreshAuth) ? sayf('Latency refreshed.\'; pingServer') : sayf(@noAuthMessage)

    return authCheck(@reqLatencyAuth) ? sayf("#{@latencyms.to_i}ms") : sayf(@noAuthMessage)
  rescue => e
    handleError(e)
    return nil
  end
end