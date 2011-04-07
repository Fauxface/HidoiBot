class Pick < BotPlugin
    def initialize
        # Authorisations
        @reqPickAuth = 0
        
        # Strings
        @noAuthMsg = "You are not authorised for this."
        
        # Required plugin stuff
        name = self.class.name
        @hook = ['pick', 'pickone']
        processEvery = false
        help = "Usage: #{@hook} (1-9) <items, seprated by commas>\nFunction: Picks n items from a list."
        super(name, @hook, processEvery, help)
    end

    def main(data)
        @givenLevel = data["authLevel"]        
        if checkAuth(@reqPickAuth)
            list = stripTrigger(data)
            picks = arguments(data)[0].to_i
            
            if !(/[1-9]/ === picks.to_s)
                picks = 1
            else
                list.gsub!("#{picks.to_s} ", '')
            end
            
            parsedList = parseOptions(list)
            
            return sayf(pick(picks, parsedList))
        else
            return sayf(@noAuthMsg)
        end
    rescue => e
        handleError(e)
        return nil
    end
    
    def pick(picks, list)
        pickItem = Array.new
        
        for i in 0..picks - 1
            pickNumber = rand(list.size)
            pickItem.push(list[pickNumber])
            list.delete_at(pickNumber)
        end
        
        return pickItem.join(', ')
    end
    
    def parseOptions(s)
        s.gsub!(', ', ',')
        return s.split(/[,]/)
    end
end