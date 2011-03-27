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
        
        if mode == 'refresh' && authCheck(@reqLatencyRefreshAuth)
            return 'pingServer; say \'Latency refreshed.\''
        elsif mode == 'refresh' && !authCheck(@reqLatencyRefreshAuth)
            reutrn sayf(@noAuthMessage)
        end
            
        if authCheck(@reqLatencyAuth)
            return 'say "#{@latencyms.to_i}ms"'
        else
            return sayf(@noAuthMessage)
        end
        
    rescue => e
        handleError(e)
        return nil
    end
end