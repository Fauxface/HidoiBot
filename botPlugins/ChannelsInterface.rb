class ChannelsInterface < BotPlugin
    def initialize
        # Required plugin stuff
        name = self.class.name
        hook = ["join", "part", "nick"]
        processEvery = false
        help = "Usage: #{hook} <term>\nFunction: Joins/parts a channel or changes the bot's nickname."
        super(name, hook, processEvery, help)
    end

    def main(data)
        @givenLevel = data["authLevel"]
        requiredLevel = 3
        
        if authCheck(requiredLevel)            
            mode = data["trigger"]
            channel = arguments(data)[0]
            
            case mode
                when 'join'
                    return "joinChannel('#{channel}')"
                when 'part'
                    return "partChannel('#{channel}')"
                when 'nick'
                    return "send 'NICK #{channel}'"
            end
        else
            return sayf('You are not authorised for this.')
        end
    rescue => e
        handleError(e)
        return nil
    end
end