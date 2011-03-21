# Dangerous!

class Script < BotPlugin
    def initialize
        # Authorisations
        @reqScriptLevel = 3
        @requiredScriptStatusLevel = 0
        
        # Strings
        @noAuthMessage = 'You are not authorised for this.'
        @scriptingOnMessage = 'Scripting is now on.'
        @scriptingOffMessage ='Scripting is now off.' 
        
        # Is scripting turned on by default?
        @scripting = false
        
        # Required plugin stuff
        name = self.class.name
        @hook = 'script'
        processEvery = false
        help = "Usage: #{@hook} (on|off|status|<term>)\nFunction: Evaluates term."
        super(name, @hook, processEvery, help)
    end

    def main(data)
        @givenLevel = data["authLevel"]
        toEval = stripTrigger(data)
        mode = arguments(data)[0]
        
        case mode
            when 'on'
                requiredLevel = @reqScriptLevel
                if authCheck(requiredLevel)
                    @scripting = true
                    return sayf(@scriptingOnMessage)
                else
                    return sayf(@noAuthMessage)
                end
                
            when 'off'
                requiredLevel = @reqScriptLevel
                if authCheck(requiredLevel)
                    @scripting = false
                    return sayf(@scriptingOffMessage)
                else
                    return sayf(@noAuthMessage)
                end
                
            when 'status'
                requiredLevel = @requiredScriptStatusLevel
                if authCheck(requiredLevel)
                    return sayf(getScriptingStatus)
                else
                    return sayf(@noAuthMessage)
                end
                
            else
                requiredLevel = @reqScriptLevel
                if authCheck(requiredLevel)
                    rs = eval(toEval)
                    return sayf(rs)
                else
                    return sayf(@noAuthMessage)
                end
        end
        
    rescue => e
        handleError(e)
        return sayf(e)
    end
    
    def getScriptingStatus
        if @scripting == true
            return @scriptingOnMessage
        elsif @scripting == false
            return @scriptingOffMessage
        end
    end
end