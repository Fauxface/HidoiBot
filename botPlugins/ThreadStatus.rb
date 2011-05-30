class ThreadStatus < BotPlugin
    def initialize
        # Authorisations
        @requiredAuth = 0
        
        # Strings
        @noAuthMsg = "You are not authorised for this."
        
        # Required plugin stuff
        name = self.class.name
        hook = 'threads'
        processEvery = false
        help = "Function: Returns running threads."
        super(name, hook, processEvery, help)
    end

    def main(data)
        @givenLevel = data["authLevel"]
        
        if authCheck(@requiredAuth)
            return sayf(threadInfo)
        else
            return sayf(@noAuthMsg)
        end
    rescue => e
        handleError(e)
        return nil
    end
    
    def threadInfo()
        return Thread.list.join("\n")
    end
end