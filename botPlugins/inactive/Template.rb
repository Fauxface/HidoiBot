class Template < BotPlugin
    def initialize
        # Authorisations
        
        # Strings
        
        # Required plugin stuff
        name = self.class.name
        @hook = nil
        processEvery = false
        help = "Usage: #{@hook} <term>\nFunction: fgsfds."
        super(name, @hook, processEvery, help)
    end

    def main(data)
        @givenLevel = data["authLevel"]
        
        mode = arguments(data)[0]
        
        case mode
            when 'a'
                return nil
            else
                return "say 'foo bar'"
        end
    rescue => e
        handleError(e)
        return nil
    end
end